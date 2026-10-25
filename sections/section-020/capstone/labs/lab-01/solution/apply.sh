#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the learner starts from the seeded state.
# Taken from solution.md - if one changes, change the other.
#
# `astrona test` has no port-forward to Gitea, so every Git change goes through
# the Gitea API from the tester pod. The learner may use git instead.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITEA_API="http://gitea-http.gitea.svc.cluster.local:3000/api/v1"
OWNER_AUTH="starfleet:starfleet-password"   # lab-only credentials
REPO_PATH="/repos/starfleet/bridge-app"
CONTROLLER_URL="http://pipelines-as-code-controller.pipelines-as-code.svc.cluster.local:8080"

gitea_api() {
  # gitea_api USER:PASSWORD METHOD PATH [JSON]: calls the Gitea API from the tester pod.
  local auth="$1" method="$2" path="$3" body="${4:-}"
  if [ -n "$body" ]; then
    kubectl -n gitea exec deploy/tester -- curl -fsS -u "$auth" -X "$method" \
      -H 'Content-Type: application/json' --data "$body" "$GITEA_API$path"
  else
    kubectl -n gitea exec deploy/tester -- curl -fsS -u "$auth" -X "$method" "$GITEA_API$path"
  fi
}

gitea_query() {
  # gitea_query USER:PASSWORD PATH JQ_FILTER: GET and filter with jq in the tester pod.
  kubectl -n gitea exec deploy/tester -- sh -c 'curl -fsS -u "$1" "$2" | jq -r "$3"' \
    _ "$1" "$GITEA_API$2" "$3"
}

put_file() {
  # put_file USER:PASSWORD OWNER/REPO BRANCH LOCAL_FILE REPO_PATH MESSAGE:
  # creates or updates one file on one branch (an existing file needs its sha).
  local auth="$1" repo="$2" branch="$3" file="$4" path="$5" message="$6" content sha
  content="$(base64 < "$file" | tr -d '\n')"
  sha="$(gitea_query "$auth" "/repos/$repo/contents/$path?ref=$branch" '.sha // empty' 2>/dev/null || true)"
  if [ -n "$sha" ]; then
    gitea_api "$auth" PUT "/repos/$repo/contents/$path" \
      "{\"content\":\"$content\",\"sha\":\"$sha\",\"message\":\"$message\",\"branch\":\"$branch\"}" >/dev/null
  else
    gitea_api "$auth" POST "/repos/$repo/contents/$path" \
      "{\"content\":\"$content\",\"message\":\"$message\",\"branch\":\"$branch\"}" >/dev/null
  fi
}

wait_for_pipelinerun() {
  # wait_for_pipelinerun SHA NAME: waits until a PipelineRun from the .tekton
  # PipelineRun NAME exists for the commit and has finished.
  local run condition
  for _ in $(seq 1 60); do
    run="$(kubectl -n starfleet get pipelineruns \
      -l "pipelinesascode.tekton.dev/sha=$1,pipelinesascode.tekton.dev/original-prname=$2" \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
    if [ -n "$run" ]; then
      condition="$(kubectl -n starfleet get pipelinerun "$run" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}')"
      if [ "$condition" = "True" ] || [ "$condition" = "False" ]; then
        echo "[solution] PipelineRun $run ended with Succeeded=$condition."
        return 0
      fi
    fi
    sleep 5
  done
  echo "ERROR: no finished PipelineRun $2 for $1." >&2
  return 1
}

delete_file() {
  # delete_file BRANCH REPO_PATH MESSAGE: deletes one file, if it exists.
  local sha
  sha="$(gitea_query "$OWNER_AUTH" "$REPO_PATH/contents/$2?ref=$1" '.sha // empty' 2>/dev/null || true)"
  [ -n "$sha" ] || return 0
  kubectl -n gitea exec deploy/tester -- curl -fsS -u "$OWNER_AUTH" -X DELETE \
    -H 'Content-Type: application/json' \
    --data "{\"sha\":\"$sha\",\"message\":\"$3\",\"branch\":\"$1\"}" \
    "$GITEA_API$REPO_PATH/contents/$2" >/dev/null
}

# 1. Remove the old copy that reuses the name push.
delete_file main .tekton/push-copy.yaml "Remove the old copy of the push pipeline"

# 2. Replace the CEL expression with on-target-branch [main, release-*] and
#    keep three runs. This commit to main is itself a push that runs push.
put_file "$OWNER_AUTH" starfleet/bridge-app main "$SCRIPT_DIR/push.yaml" \
  .tekton/push.yaml "Run the push pipeline for main and release branches"

sha="$(gitea_query "$OWNER_AUTH" "$REPO_PATH/branches/main" '.commit.id')"
wait_for_pipelinerun "$sha" push

# 3. A push uses the .tekton folder of the pushed commit, so release-1.0
#    needs the same two changes.
delete_file release-1.0 .tekton/push-copy.yaml "Remove the old copy of the push pipeline"
put_file "$OWNER_AUTH" starfleet/bridge-app release-1.0 "$SCRIPT_DIR/push.yaml" \
  .tekton/push.yaml "Run the push pipeline for main and release branches"
sha="$(gitea_query "$OWNER_AUTH" "$REPO_PATH/branches/release-1.0" '.commit.id')"
wait_for_pipelinerun "$sha" push
