#!/usr/bin/env bash
# PASS when the pull request from cadet's fork (branch docs-typo) is tested:
# the repository owner starfleet commented /ok-to-test on it, and the head
# commit has a successful PipelineRun pull-request that checked out exactly
# that commit, with the status success in Gitea.
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

pr="$(gitea_query "$OWNER_AUTH" "$REPO_PATH/pulls?state=open" \
  '[.[] | select(.head.ref == "docs-typo" and .user.login == "cadet")][0] | "\(.number) \(.head.sha)"')"
number="${pr%% *}"
sha="${pr#* }"
if [ -z "$pr" ] || [ "$number" = "null" ]; then
  echo "FAIL: the pull request from cadet:docs-typo is not open."
  exit 1
fi

approvals="$(gitea_query "$OWNER_AUTH" "$REPO_PATH/issues/$number/comments" \
  '[.[] | select(.user.login == "starfleet" and (.body | test("^/ok-to-test"; "m")))] | length')"
if [ "${approvals:-0}" -lt 1 ]; then
  echo "FAIL: nobody with rights on the repository commented /ok-to-test on pull request #$number."
  exit 1
fi

run="$(wait_for_run "$sha" pull-request 36)"
if [ -z "$run" ]; then
  echo "FAIL: no PipelineRun pull-request ran for the head commit $sha of pull request #$number."
  exit 1
fi
condition="$(run_condition "$run")"
if [ "$condition" != "True" ]; then
  echo "FAIL: PipelineRun $run has Succeeded=${condition:-none}."
  exit 1
fi
commit="$(kubectl -n "$NS" get pipelinerun "$run" -o jsonpath='{.status.results[?(@.name=="commit")].value}')"
if [ "$commit" != "$sha" ]; then
  echo "FAIL: PipelineRun $run checked out '$commit', expected the pull request head $sha."
  exit 1
fi
if ! value="$(wait_for_commit_status "$sha" "$CHECK_PREFIX / pull-request" success 24)"; then
  echo "FAIL: commit $sha has the status '${value:-none}' for '$CHECK_PREFIX / pull-request', expected success."
  exit 1
fi

echo "PASS: pull request #$number from cadet was approved with /ok-to-test and $run succeeded on $sha."
exit 0
