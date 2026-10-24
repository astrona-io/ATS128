#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the learner starts from the seeded state.
# Taken from solution.md - if one changes, change the other.
#
# `astrona test` has no port-forward to Gitea, so every Git change goes through
# the Gitea API from the tester pod. The learner may use git instead.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITEA_API="http://gitea-http.gitea:3000/api/v1"
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

# 1. Use one webhook secret on both sides: write a new one into the Secret and
#    recreate the Gitea webhook with it (Gitea cannot change the secret of an
#    existing webhook).
NEW_SECRET="bridge-webhook-secret-2"
kubectl -n starfleet patch secret gitea-webhook-config --type merge \
  -p "{\"stringData\":{\"webhook.secret\":\"$NEW_SECRET\"}}"
for id in $(gitea_query "$OWNER_AUTH" "$REPO_PATH/hooks" '.[].id'); do
  gitea_api "$OWNER_AUTH" DELETE "$REPO_PATH/hooks/$id" >/dev/null
done
gitea_api "$OWNER_AUTH" POST "$REPO_PATH/hooks" \
  "{\"type\":\"gitea\",\"active\":true,\"branch_filter\":\"*\",\"events\":[\"push\",\"pull_request\",\"pull_request_sync\",\"pull_request_comment\"],\"config\":{\"url\":\"$CONTROLLER_URL\",\"content_type\":\"json\",\"secret\":\"$NEW_SECRET\"}}" >/dev/null

# 2. As the owner, approve cadet's pull request with /ok-to-test.
number="$(gitea_query "$OWNER_AUTH" "$REPO_PATH/pulls?state=open" '[.[] | select(.head.ref == "docs-typo")][0].number')"
gitea_api "$OWNER_AUTH" POST "$REPO_PATH/issues/$number/comments" '{"body":"/ok-to-test"}' >/dev/null
sha="$(gitea_query "$OWNER_AUTH" "$REPO_PATH/pulls/$number" '.head.sha')"
wait_for_pipelinerun "$sha" pull-request

# 3. Trust cadet for later pull requests through OWNERS on main.
put_file "$OWNER_AUTH" starfleet/bridge-app main "$SCRIPT_DIR/OWNERS" OWNERS "Trust cadet as a reviewer"
