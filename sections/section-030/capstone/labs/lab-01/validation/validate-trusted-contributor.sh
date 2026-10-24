#!/usr/bin/env bash
# PASS when cadet is trusted for later changes: the grader, as cadet, pushes a
# new commit to the branch docs-typo of cadet's fork. Pipelines-as-Code must
# run pull-request for that commit without a new /ok-to-test, and it must
# succeed.
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
CADET_AUTH="cadet:cadet-password"   # lab-only credentials

stamp="$(date +%s)"
content="$(printf 'grader check %s\n' "$stamp" | base64 | tr -d '\n')"
sha="$(kubectl -n gitea exec deploy/tester -- sh -c \
  'curl -fsS -u "$1" -X POST -H "Content-Type: application/json" --data "$2" "$3" | jq -r ".commit.sha // empty"' \
  _ "$CADET_AUTH" "{\"content\":\"$content\",\"message\":\"Grader check\",\"branch\":\"docs-typo\"}" \
  "$GITEA_API/repos/cadet/bridge-app/contents/grader/check-$stamp.txt" 2>/dev/null)"
if [ -z "$sha" ]; then
  echo "FAIL: the grader could not push a commit as cadet to cadet/bridge-app on docs-typo."
  exit 1
fi

run="$(wait_for_run "$sha" pull-request 48)"
if [ -z "$run" ]; then
  echo "FAIL: a new commit from cadet ($sha) started no PipelineRun. Pipelines-as-Code does not trust cadet yet."
  exit 1
fi
condition="$(run_condition "$run")"
if [ "$condition" != "True" ]; then
  echo "FAIL: PipelineRun $run for cadet's new commit has Succeeded=${condition:-none}."
  exit 1
fi

echo "PASS: a new commit from cadet ($sha) ran $run without /ok-to-test, and it succeeded."
exit 0
