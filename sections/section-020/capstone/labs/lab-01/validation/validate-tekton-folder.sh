#!/usr/bin/env bash
# PASS when the .tekton folder on main has unique PipelineRun names, exactly
# one PipelineRun named push, and that PipelineRun keeps at most three runs
# (pipelinesascode.tekton.dev/max-keep-runs: "3"). The pull request pipeline
# pull-request must still be there.
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

files="$(gitea_query "$OWNER_AUTH" "$REPO_PATH/contents/.tekton?ref=main" '.[] | select(.type == "file") | .path')"
if [ -z "$files" ]; then
  echo "FAIL: the .tekton folder on main is empty or missing."
  exit 1
fi

names=""
push_file=""
for path in $files; do
  case "$path" in *.yaml|*.yml) ;; *) continue ;; esac
  content="$(kubectl -n gitea exec deploy/tester -- curl -fsS -u "$OWNER_AUTH" \
    "$GITEA_API$REPO_PATH/raw/$path?ref=main" 2>/dev/null)"
  name="$(printf '%s\n' "$content" | awk '/^metadata:/ {inmeta=1; next} inmeta && /^  name:/ {print $2; exit} /^[^ #]/ {inmeta=0}' | tr -d '"')"
  names="$names$name"$'\n'
  if [ "$name" = "push" ]; then
    push_file="$path"
    push_content="$content"
  fi
done

duplicates="$(printf '%s' "$names" | grep -v '^$' | sort | uniq -d)"
if [ -n "$duplicates" ]; then
  echo "FAIL: several files in .tekton on main define the same PipelineRun name: $(printf '%s' "$duplicates" | tr '\n' ' ')"
  exit 1
fi
if [ -z "$push_file" ]; then
  echo "FAIL: no file in .tekton on main defines the PipelineRun push."
  exit 1
fi
if ! printf '%s\n' "$names" | grep -x 'pull-request' >/dev/null; then
  echo "FAIL: the PipelineRun pull-request is missing from .tekton on main."
  exit 1
fi
if ! printf '%s\n' "$push_content" | grep -E 'pipelinesascode\.tekton\.dev/max-keep-runs: *"3"' >/dev/null; then
  echo "FAIL: the PipelineRun push in $push_file must set pipelinesascode.tekton.dev/max-keep-runs: \"3\"."
  exit 1
fi

echo "PASS: .tekton on main has unique names; push ($push_file) keeps at most three runs."
exit 0
