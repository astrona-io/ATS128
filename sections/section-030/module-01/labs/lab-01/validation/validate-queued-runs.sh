#!/usr/bin/env bash
# PASS when the head commit of the pull request from feature-sensors has a
# successful lint run and a successful unit-test run that did not overlap:
# with concurrency_limit 1, Pipelines-as-Code starts them in alphabetical
# order, so unit-test starts only after lint completed.
set -uo pipefail

NS="starfleet"
GITEA_API="http://gitea-http.gitea.svc.cluster.local:3000/api/v1"
OWNER_AUTH="starfleet:starfleet-password"   # lab-only credentials
REPO_PATH="/repos/starfleet/bridge-app"
CHECK_PREFIX="Pipelines as Code CI"

gitea_query() {
  # gitea_query USER:PASSWORD PATH JQ_FILTER: GET one Gitea API path from the
  # tester pod and filter the JSON with jq inside the pod.
  kubectl -n gitea exec deploy/tester -- sh -c 'curl -fsS -u "$1" "$2" | jq -r "$3"' \
    _ "$1" "$GITEA_API$2" "$3" 2>/dev/null
}

runs_for() {
  # runs_for SHA NAME: the PipelineRuns that Pipelines-as-Code created for one
  # commit from the .tekton PipelineRun NAME, oldest first.
  kubectl -n "$NS" get pipelineruns \
    -l "pipelinesascode.tekton.dev/sha=$1,pipelinesascode.tekton.dev/original-prname=$2" \
    --sort-by=.metadata.creationTimestamp \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null
}

run_condition() {
  # run_condition RUN: the status of the Succeeded condition of a PipelineRun.
  kubectl -n "$NS" get pipelinerun "$1" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null
}

wait_for_run() {
  # wait_for_run SHA NAME TRIES: waits (5 s per try) until a PipelineRun for
  # the commit exists and has finished; prints the newest one's name.
  local sha="$1" name="$2" tries="$3" run condition
  for _ in $(seq 1 "$tries"); do
    run="$(runs_for "$sha" "$name" | tail -n 1)"
    if [ -n "$run" ]; then
      condition="$(run_condition "$run")"
      if [ "$condition" = "True" ] || [ "$condition" = "False" ]; then
        printf '%s\n' "$run"
        return 0
      fi
    fi
    sleep 5
  done
  runs_for "$sha" "$name" | tail -n 1
  return 1
}

commit_status() {
  # commit_status SHA CONTEXT: the newest Gitea commit status of one context.
  gitea_query "$OWNER_AUTH" "$REPO_PATH/commits/$1/statuses" \
    "[.[] | select(.context == \"$2\")] | sort_by(.id) | last | (.status // .state // empty)"
}

wait_for_commit_status() {
  # wait_for_commit_status SHA CONTEXT WANTED TRIES: waits until the newest
  # status of one context has the wanted value; prints the last value seen.
  local value=""
  for _ in $(seq 1 "$4"); do
    value="$(commit_status "$1" "$2")"
    [ "$value" = "$3" ] && break
    sleep 5
  done
  printf '%s\n' "$value"
  [ "$value" = "$3" ]
}

sha="$(gitea_query "$OWNER_AUTH" "$REPO_PATH/pulls?state=open" \
  '[.[] | select(.head.ref == "feature-sensors" and .base.ref == "main")][0].head.sha // empty')"
if [ -z "$sha" ]; then
  echo "FAIL: there is no open pull request from feature-sensors into main."
  exit 1
fi

finished_run() {
  # finished_run NAME: sets FOUND_RUN to the newest successful run of NAME for
  # the head commit, or prints FAIL and exits.
  local condition
  FOUND_RUN="$(wait_for_run "$sha" "$1" 48)"
  if [ -z "$FOUND_RUN" ]; then
    echo "FAIL: no PipelineRun $1 ran for the head commit $sha. Push a new commit to feature-sensors after setting the limit."
    exit 1
  fi
  condition="$(run_condition "$FOUND_RUN")"
  if [ "$condition" != "True" ]; then
    echo "FAIL: PipelineRun $FOUND_RUN has Succeeded=${condition:-none}."
    exit 1
  fi
}
finished_run lint
run_lint="$FOUND_RUN"
finished_run unit-test
run_unit_test="$FOUND_RUN"

lint_done="$(kubectl -n "$NS" get pipelinerun "$run_lint" -o jsonpath='{.status.completionTime}')"
test_start="$(kubectl -n "$NS" get pipelinerun "$run_unit_test" -o jsonpath='{.status.startTime}')"
if [ -z "$lint_done" ] || [ -z "$test_start" ]; then
  echo "FAIL: could not read the times of $run_lint and $run_unit_test."
  exit 1
fi
# Both times are RFC 3339 in UTC, so text order is time order.
if [[ "$test_start" < "$lint_done" ]]; then
  echo "FAIL: $run_unit_test started at $test_start, before $run_lint completed at $lint_done: the runs overlapped."
  exit 1
fi

echo "PASS: for commit $sha, $run_lint completed at $lint_done and $run_unit_test started after it, at $test_start."
exit 0
