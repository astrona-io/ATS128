#!/usr/bin/env bash
# PASS when Pipelines-as-Code keeps at most three finished runs of the
# PipelineRun push. The grader commits to main until at least four push runs
# have existed, waits for its runs, then waits for the cleanup.
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

count_push_runs() {
  kubectl -n "$NS" get pipelineruns \
    -l "pipelinesascode.tekton.dev/repository=bridge-app,pipelinesascode.tekton.dev/original-prname=push" \
    -o name 2>/dev/null | grep -c . || true
}

grader_commit() {
  local stamp content
  stamp="$(date +%s)-$1"
  content="$(printf 'grader cleanup check %s\n' "$stamp" | base64 | tr -d '\n')"
  kubectl -n gitea exec deploy/tester -- sh -c \
    'curl -fsS -u "$1" -X POST -H "Content-Type: application/json" --data "$2" "$3" | jq -r ".commit.sha // empty"' \
    _ "$OWNER_AUTH" "{\"content\":\"$content\",\"message\":\"Grader cleanup check\",\"branch\":\"main\"}" \
    "$GITEA_API$REPO_PATH/contents/grader/cleanup-$stamp.txt" 2>/dev/null
}

# Make sure at least four push runs have existed, then let one more finish:
# the cleanup runs after each successful run.
existing="$(count_push_runs)"
needed=$((4 - existing))
[ "$needed" -lt 1 ] && needed=1
# One commit at a time: the run waited for is always the newest, so the
# cleanup never removes it while the grader waits.
for attempt in $(seq 1 "$needed"); do
  sha="$(grader_commit "$attempt")"
  if [ -z "$sha" ]; then
    echo "FAIL: the grader could not commit to main."
    exit 1
  fi
  if ! run="$(wait_for_run "$sha" push 36)"; then
    echo "FAIL: a push to main (commit $sha) started no finished PipelineRun push."
    exit 1
  fi
done

count=""
for _ in $(seq 1 24); do
  count="$(count_push_runs)"
  [ "$count" -le 3 ] && break
  sleep 5
done
if [ "$count" -gt 3 ]; then
  echo "FAIL: $count PipelineRuns of push are kept; max-keep-runs \"3\" should keep three."
  exit 1
fi

echo "PASS: Pipelines-as-Code keeps $count runs of push after at least four pushes."
exit 0
