#!/usr/bin/env bash
# PASS when the push pipeline runs for the right branches: the grader commits
# one file to feature-engines, one to main and one to release-1.0. The commits
# on main and release-1.0 must each get a successful PipelineRun push (and a
# success status in Gitea); the commit on feature-engines must get none.
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

grader_commit() {
  # grader_commit BRANCH: commits grader/<branch>-<time>.txt to BRANCH and
  # prints the new commit SHA.
  local branch="$1" stamp content
  stamp="$(date +%s)"
  content="$(printf 'grader check %s\n' "$stamp" | base64 | tr -d '\n')"
  kubectl -n gitea exec deploy/tester -- sh -c \
    'curl -fsS -u "$1" -X POST -H "Content-Type: application/json" --data "$2" "$3" | jq -r ".commit.sha // empty"' \
    _ "$OWNER_AUTH" "{\"content\":\"$content\",\"message\":\"Grader check on $branch\",\"branch\":\"$branch\"}" \
    "$GITEA_API$REPO_PATH/contents/grader/$branch-$stamp.txt" 2>/dev/null
}

feature_sha="$(grader_commit feature-engines)"
main_sha="$(grader_commit main)"
release_sha="$(grader_commit release-1.0)"
if [ -z "$feature_sha" ] || [ -z "$main_sha" ] || [ -z "$release_sha" ]; then
  echo "FAIL: the grader could not commit to feature-engines, main and release-1.0 (do the branches still exist?)."
  exit 1
fi

for pair in "main:$main_sha" "release-1.0:$release_sha"; do
  branch="${pair%%:*}"
  sha="${pair#*:}"
  run="$(wait_for_run "$sha" push 36)"
  if [ -z "$run" ]; then
    echo "FAIL: a push to $branch (commit $sha) started no PipelineRun push."
    exit 1
  fi
  condition="$(run_condition "$run")"
  if [ "$condition" != "True" ]; then
    echo "FAIL: PipelineRun $run for the push to $branch has Succeeded=${condition:-none}."
    exit 1
  fi
  if ! value="$(wait_for_commit_status "$sha" "$CHECK_PREFIX / push" success 24)"; then
    echo "FAIL: commit $sha on $branch has the status '${value:-none}' for '$CHECK_PREFIX / push', expected success."
    exit 1
  fi
done

# The feature-engines commit was pushed first, so its event was handled
# before the two runs above finished.
sleep 10
stray="$(kubectl -n "$NS" get pipelineruns -l "pipelinesascode.tekton.dev/sha=$feature_sha" -o name 2>/dev/null)"
if [ -n "$stray" ]; then
  echo "FAIL: a push to feature-engines started $(printf '%s' "$stray" | tr '\n' ' '); the push pipeline must run only for main and release-* branches."
  exit 1
fi

echo "PASS: pushes to main and release-1.0 ran the PipelineRun push and reported success; a push to feature-engines ran nothing."
exit 0
