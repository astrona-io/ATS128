#!/usr/bin/env bash
# Creates the starting state for ats-128-capstone-030.
#
# 1. Seeds starfleet/bridge-app with .tekton/pull-request.yaml.
# 2. Connects it with a fault: the Secret gitea-webhook-config holds an old
#    webhook secret, so Pipelines-as-Code rejects every event from Gitea.
# 3. The user cadet (no rights on the repository) forks it, changes
#    docs/guide.md on the branch docs-typo and opens pull request #1.
#
# Getting the pull request tested and trusting cadet is the task.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR=""
for candidate in "$SCRIPT_DIR/../manifests" "./manifests" "$SCRIPT_DIR/manifests"; do
  [ -d "$candidate" ] && { MANIFEST_DIR="$candidate"; break; }
done
[ -n "$MANIFEST_DIR" ] || { echo "ERROR: manifests folder not found." >&2; exit 1; }

apply_with_retry() {
  # apply_with_retry ARGS...: the admission webhooks can refuse the first objects.
  local attempt
  for attempt in $(seq 1 30); do
    kubectl apply "$@" && return 0
    echo "[seed] kubectl apply $* failed (attempt $attempt), retrying in 5s..."
    sleep 5
  done
  return 1
}


GITEA_API="http://gitea-http.gitea:3000/api/v1"
GITEA_URL="http://gitea-http.gitea.svc.cluster.local:3000"
OWNER="starfleet"
OWNER_AUTH="starfleet:starfleet-password"   # lab-only credentials
CADET_AUTH="cadet:cadet-password"           # lab-only credentials
REPO="bridge-app"
REPO_URL="$GITEA_URL/$OWNER/$REPO"
CONTROLLER_URL="http://pipelines-as-code-controller.pipelines-as-code.svc.cluster.local:8080"
WEBHOOK_SECRET="bridge-webhook-secret"      # lab-only shared secret

gitea_api() {
  # gitea_api USER:PASSWORD METHOD PATH [JSON]: calls the Gitea API from the
  # tester pod and prints the response body. Fails on an HTTP error. The body
  # travels as an argument, not through stdin.
  local auth="$1" method="$2" path="$3" body="${4:-}"
  if [ -n "$body" ]; then
    kubectl -n gitea exec deploy/tester -- curl -fsS -u "$auth" -X "$method" \
      -H 'Content-Type: application/json' --data "$body" "$GITEA_API$path"
  else
    kubectl -n gitea exec deploy/tester -- curl -fsS -u "$auth" -X "$method" "$GITEA_API$path"
  fi
}

gitea_query() {
  # gitea_query USER:PASSWORD PATH JQ_FILTER: GET one API path and filter the
  # JSON with jq, both inside the tester pod.
  kubectl -n gitea exec deploy/tester -- sh -c 'curl -fsS -u "$1" "$2" | jq -r "$3"' \
    _ "$1" "$GITEA_API$2" "$3"
}

ensure_repository() {
  # ensure_repository: creates the public repository starfleet/bridge-app with
  # a README on the branch main, once.
  if ! gitea_api "$OWNER_AUTH" GET "/repos/$OWNER/$REPO" >/dev/null 2>&1; then
    echo "[seed] Creating the repository $OWNER/$REPO..."
    gitea_api "$OWNER_AUTH" POST "/user/repos" \
      "{\"name\":\"$REPO\",\"auto_init\":true,\"default_branch\":\"main\",\"private\":false}" >/dev/null
  fi
}

put_file() {
  # put_file AUTH OWNER/REPO BRANCH LOCAL_FILE REPO_PATH MESSAGE: creates or
  # updates one file on one branch. An existing file needs PUT with its sha.
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

sync_file() {
  # sync_file AUTH OWNER/REPO BRANCH LOCAL_FILE REPO_PATH MESSAGE: commits the
  # file only when the branch does not already hold the same content.
  local current wanted
  wanted="$(base64 < "$4" | tr -d '\n')"
  current="$(gitea_query "$1" "/repos/$2/contents/$5?ref=$3" '.content // empty' 2>/dev/null | tr -d '\n' || true)"
  [ "$current" = "$wanted" ] && return 0
  put_file "$1" "$2" "$3" "$4" "$5" "$6"
}

seed_tree() {
  # seed_tree LOCAL_DIR BRANCH: commits every file under LOCAL_DIR (hidden
  # folders such as .tekton included) to the branch, one commit per file.
  local dir="$1" branch="$2" file
  for file in $(cd "$dir" && find . -type f | sed 's|^\./||' | sort); do
    sync_file "$OWNER_AUTH" "$OWNER/$REPO" "$branch" "$dir/$file" "$file" "Add $file"
  done
}

ensure_branch() {
  # ensure_branch NAME: creates a branch from main, once.
  if ! gitea_api "$OWNER_AUTH" GET "/repos/$OWNER/$REPO/branches/$1" >/dev/null 2>&1; then
    gitea_api "$OWNER_AUTH" POST "/repos/$OWNER/$REPO/branches" \
      "{\"new_branch_name\":\"$1\",\"old_branch_name\":\"main\"}" >/dev/null
  fi
}

open_pull_request() {
  # open_pull_request AUTH HEAD TITLE: opens a pull request into main, once,
  # and prints its number. HEAD is a branch, or OWNER:BRANCH for a fork.
  local auth="$1" head="$2" title="$3" branch number
  branch="${head#*:}"
  number="$(gitea_query "$OWNER_AUTH" "/repos/$OWNER/$REPO/pulls?state=open" \
    "[.[] | select(.head.ref == \"$branch\")][0].number // empty")"
  if [ -z "$number" ]; then
    number="$(gitea_api "$auth" POST "/repos/$OWNER/$REPO/pulls" \
      "{\"head\":\"$head\",\"base\":\"main\",\"title\":\"$title\"}" >/dev/null && \
      gitea_query "$OWNER_AUTH" "/repos/$OWNER/$REPO/pulls?state=open" \
      "[.[] | select(.head.ref == \"$branch\")][0].number // empty")"
  fi
  [ -n "$number" ] || { echo "ERROR: could not open the pull request from $head." >&2; return 1; }
  printf '%s\n' "$number"
}

pull_request_head() {
  # pull_request_head NUMBER: prints the head commit SHA of a pull request.
  gitea_query "$OWNER_AUTH" "/repos/$OWNER/$REPO/pulls/$1" '.head.sha'
}

recreate_webhook() {
  # recreate_webhook URL SECRET: removes every webhook of the repository and
  # creates one Gitea webhook. Gitea ignores a new secret in PATCH, so a
  # webhook is always deleted and created again.
  local id ids
  ids="$(gitea_query "$OWNER_AUTH" "/repos/$OWNER/$REPO/hooks" '.[].id')"
  for id in $ids; do
    gitea_api "$OWNER_AUTH" DELETE "/repos/$OWNER/$REPO/hooks/$id" >/dev/null
  done
  gitea_api "$OWNER_AUTH" POST "/repos/$OWNER/$REPO/hooks" \
    "{\"type\":\"gitea\",\"active\":true,\"branch_filter\":\"*\",\"events\":[\"push\",\"pull_request\",\"pull_request_sync\",\"pull_request_comment\"],\"config\":{\"url\":\"$1\",\"content_type\":\"json\",\"secret\":\"$2\"}}" >/dev/null
}

create_provider_secret() {
  # create_provider_secret NAMESPACE NAME TOKEN_KEY WEBHOOK_KEY WEBHOOK_SECRET:
  # a Secret with the Gitea token and the webhook secret.
  local token
  token="$(kubectl -n gitea get secret gitea-token -o jsonpath='{.data.token}' | base64 -d)"
  kubectl -n "$1" create secret generic "$2" \
    --from-literal="$3=$token" --from-literal="$4=$5" \
    --dry-run=client -o yaml | kubectl apply -f -
}

wait_for_runs() {
  # wait_for_runs SHA COUNT: waits until COUNT PipelineRuns for one commit
  # exist in starfleet and all of them have finished.
  local sha="$1" count="$2" found finished
  for _ in $(seq 1 100); do
    found="$(kubectl -n starfleet get pipelineruns -l "pipelinesascode.tekton.dev/sha=$sha" \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep -c . || true)"
    finished="$(kubectl -n starfleet get pipelineruns -l "pipelinesascode.tekton.dev/sha=$sha" \
      -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Succeeded")].status}{"\n"}{end}' 2>/dev/null \
      | grep -cE '^(True|False)$' || true)"
    if [ "${found:-0}" -ge "$count" ] && [ "${finished:-0}" -ge "$count" ]; then
      echo "[seed] $finished PipelineRun(s) for $sha finished."
      return 0
    fi
    sleep 5
  done
  echo "ERROR: the PipelineRuns for $sha did not finish in time." >&2
  return 1
}

connect_repository() {
  # connect_repository: the Secret gitea-webhook-config, the Repository
  # bridge-app in starfleet and the Gitea webhook to the controller.
  create_provider_secret starfleet gitea-webhook-config provider.token webhook.secret "$WEBHOOK_SECRET"
  apply_with_retry -f "$MANIFEST_DIR/repository-bridge-app.yaml"
  recreate_webhook "$CONTROLLER_URL" "$WEBHOOK_SECRET"
}

# ---------------------------------------------------------------------------
# The starting state of this environment.
# ---------------------------------------------------------------------------
ensure_repository
echo "[seed] Seeding main with the application and .tekton/pull-request.yaml..."
seed_tree "$MANIFEST_DIR/repo" main
echo "[seed] Connecting the repository with a mismatched webhook secret..."
# Fault: the Secret holds an old webhook secret; the Gitea webhook signs with
# another one. Pipelines-as-Code rejects every event.
create_provider_secret starfleet gitea-webhook-config provider.token webhook.secret old-webhook-secret
apply_with_retry -f "$MANIFEST_DIR/repository-bridge-app.yaml"
recreate_webhook "$CONTROLLER_URL" "$WEBHOOK_SECRET"

echo "[seed] cadet forks the repository and opens a pull request..."
if ! gitea_api "$CADET_AUTH" GET "/repos/cadet/$REPO" >/dev/null 2>&1; then
  gitea_api "$CADET_AUTH" POST "/repos/$OWNER/$REPO/forks" "{}" >/dev/null
fi
fork_ready=false
for _ in $(seq 1 30); do
  if gitea_api "$CADET_AUTH" GET "/repos/cadet/$REPO/branches/main" >/dev/null 2>&1; then
    fork_ready=true; break
  fi
  sleep 2
done
[ "$fork_ready" = true ] || { echo "ERROR: the fork cadet/$REPO is not ready." >&2; exit 1; }
if ! gitea_api "$CADET_AUTH" GET "/repos/cadet/$REPO/branches/docs-typo" >/dev/null 2>&1; then
  gitea_api "$CADET_AUTH" POST "/repos/cadet/$REPO/branches" \
    "{\"new_branch_name\":\"docs-typo\",\"old_branch_name\":\"main\"}" >/dev/null
fi
sync_file "$CADET_AUTH" "cadet/$REPO" docs-typo "$MANIFEST_DIR/branches/docs-typo/docs/guide.md" docs/guide.md "Explain the status line in the guide"
number="$(open_pull_request "$CADET_AUTH" "cadet:docs-typo" "Explain the status line in the guide")"
echo "[lab] Pull request #$number from cadet is open. No PipelineRun ran for it."
echo "[lab] Starting state ready. Getting it tested, and trusting cadet for later pull requests, is the task."
