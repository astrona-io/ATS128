#!/usr/bin/env bash
# PASS when the open pull request from feature-shields into main has a
# PipelineRun from .tekton/pull-request.yaml for its current head commit, the
# run succeeded, and it checked out exactly that commit (the revision
# parameter comes from the dynamic variable, not a fixed branch).
set -uo pipefail

NS="starfleet"
GITEA_API="http://gitea-http.gitea:3000/api/v1"
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
  '[.[] | select(.head.ref == "feature-shields")][0] | "\(.number) \(.base.ref) \(.head.sha)"')"
read -r number base sha <<< "$pr"
if [ -z "$pr" ] || [ "$number" = "null" ]; then
  echo "FAIL: there is no open pull request from feature-shields in starfleet/bridge-app."
  exit 1
fi
if [ "$base" != "main" ]; then
  echo "FAIL: pull request #$number targets '$base'; it must stay a pull request into main."
  exit 1
fi

run="$(wait_for_run "$sha" pull-request 36)"
if [ -z "$run" ]; then
  echo "FAIL: no PipelineRun from .tekton/pull-request.yaml ran for the head commit $sha of pull request #$number. Did the fix reach the branch feature-shields?"
  exit 1
fi
condition="$(run_condition "$run")"
if [ "$condition" != "True" ]; then
  reason="$(kubectl -n "$NS" get pipelinerun "$run" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].reason}')"
  echo "FAIL: PipelineRun $run has Succeeded=${condition:-none} (reason: ${reason:-none})."
  exit 1
fi
event_type="$(kubectl -n "$NS" get pipelinerun "$run" -o jsonpath='{.metadata.labels.pipelinesascode\.tekton\.dev/event-type}')"
if [ "$event_type" != "pull_request" ]; then
  echo "FAIL: PipelineRun $run has event-type '$event_type', expected pull_request."
  exit 1
fi
commit="$(kubectl -n "$NS" get pipelinerun "$run" -o jsonpath='{.status.results[?(@.name=="commit")].value}')"
if [ "$commit" != "$sha" ]; then
  echo "FAIL: PipelineRun $run checked out '$commit', not the pull request head $sha. The revision parameter must use the revision dynamic variable."
  exit 1
fi

echo "PASS: PipelineRun $run tested commit $sha of pull request #$number and succeeded."
exit 0
