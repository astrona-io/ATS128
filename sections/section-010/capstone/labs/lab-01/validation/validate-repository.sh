#!/usr/bin/env bash
# PASS when the Repository bridge-app in starfleet connects the Gitea
# repository: the right URL, provider type gitea (or forgejo), the Gitea API
# URL, a token that Gitea accepts for the user starfleet, a non-empty webhook
# secret, and no other Repository in the cluster for the same URL.
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
REPO_URL="http://gitea-http.gitea.svc.cluster.local:3000/starfleet/bridge-app"

if ! kubectl -n "$NS" get repository bridge-app >/dev/null 2>&1; then
  echo "FAIL: Repository bridge-app does not exist in $NS."
  exit 1
fi
field() { kubectl -n "$NS" get repository bridge-app -o jsonpath="$1" 2>/dev/null; }

url="$(field '{.spec.url}')"
if [ "${url%/}" != "$REPO_URL" ]; then
  echo "FAIL: Repository bridge-app has spec.url '$url', expected '$REPO_URL'."
  exit 1
fi
type="$(field '{.spec.git_provider.type}')"
case "$type" in
  gitea|forgejo) ;;
  *) echo "FAIL: spec.git_provider.type is '${type}', expected gitea."; exit 1 ;;
esac
api_url="$(field '{.spec.git_provider.url}')"
if ! printf '%s\n' "${api_url%/}" | grep -Ex 'http://gitea-http\.gitea(\.svc(\.cluster\.local)?)?:3000' >/dev/null; then
  echo "FAIL: spec.git_provider.url is '${api_url}', expected the Gitea address http://gitea-http.gitea.svc.cluster.local:3000."
  exit 1
fi

secret_name="$(field '{.spec.git_provider.secret.name}')"
secret_key="$(field '{.spec.git_provider.secret.key}')"
secret_key="${secret_key:-provider.token}"
token="$(kubectl -n "$NS" get secret "$secret_name" -o jsonpath="{.data.${secret_key//./\\.}}" 2>/dev/null | base64 -d 2>/dev/null)"
if [ -z "$secret_name" ] || [ -z "$token" ]; then
  echo "FAIL: spec.git_provider.secret must name a Secret in $NS with the Gitea token under '${secret_key}' (found secret '${secret_name}', empty value)."
  exit 1
fi
login="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -fsS -H "Authorization: token $1" "$2" | jq -r .login' \
  _ "$token" "$GITEA_API/user" 2>/dev/null)"
if [ "$login" != "starfleet" ]; then
  echo "FAIL: Gitea does not accept the token in Secret ${secret_name}/${secret_key} for the user starfleet."
  exit 1
fi

hook_name="$(field '{.spec.git_provider.webhook_secret.name}')"
hook_key="$(field '{.spec.git_provider.webhook_secret.key}')"
hook_key="${hook_key:-webhook.secret}"
hook_secret="$(kubectl -n "$NS" get secret "$hook_name" -o jsonpath="{.data.${hook_key//./\\.}}" 2>/dev/null | base64 -d 2>/dev/null)"
if [ -z "$hook_name" ] || [ -z "$hook_secret" ]; then
  echo "FAIL: spec.git_provider.webhook_secret must name a Secret in $NS with a non-empty webhook secret under '${hook_key}'."
  exit 1
fi

others="$(kubectl get repositories -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} {.spec.url}{"\n"}{end}' 2>/dev/null \
  | awk -v want="$REPO_URL" '{u=$2; sub(/\/$/, "", u)} u == want && $1 != "starfleet/bridge-app" {print $1}')"
if [ -n "$others" ]; then
  echo "FAIL: other Repository objects use the same URL: $others."
  exit 1
fi

echo "PASS: Repository bridge-app connects $REPO_URL with a working Gitea token and a webhook secret."
exit 0
