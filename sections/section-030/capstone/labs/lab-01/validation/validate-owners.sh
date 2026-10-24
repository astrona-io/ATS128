#!/usr/bin/env bash
# PASS when the OWNERS file on main lists cadet as an approver or reviewer,
# and cadet is NOT a collaborator of starfleet/bridge-app (trust comes from
# OWNERS, not from write access to the repository).
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

owners="$(kubectl -n gitea exec deploy/tester -- curl -fsS -u "$OWNER_AUTH" \
  "$GITEA_API$REPO_PATH/raw/OWNERS?ref=main" 2>/dev/null)"
if [ -z "$owners" ]; then
  echo "FAIL: there is no OWNERS file at the top of main."
  exit 1
fi
listed="$(printf '%s\n' "$owners" | awk '
  /^(approvers|reviewers):/ {inlist=1; next}
  /^[^ -]/ {inlist=0}
  inlist && /^[[:space:]]*-[[:space:]]*/ {sub(/^[[:space:]]*-[[:space:]]*/, ""); gsub(/["\047]/, ""); print}')"
if ! printf '%s\n' "$listed" | grep -x 'cadet' >/dev/null; then
  echo "FAIL: OWNERS on main does not list cadet under approvers or reviewers."
  exit 1
fi

code="$(kubectl -n gitea exec deploy/tester -- curl -s -o /dev/null -w '%{http_code}' -u "$OWNER_AUTH" \
  "$GITEA_API$REPO_PATH/collaborators/cadet" 2>/dev/null)"
if [ "$code" = "204" ]; then
  echo "FAIL: cadet is a collaborator of starfleet/bridge-app. Trust cadet through OWNERS, without write access."
  exit 1
fi

echo "PASS: OWNERS on main lists cadet, and cadet has no write access to the repository."
exit 0
