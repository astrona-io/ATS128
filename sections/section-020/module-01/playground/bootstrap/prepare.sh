#!/usr/bin/env bash
# Installs the environment for ats-128-playground-020-01.
#
# Playground preparation only. There is no task and no grading.
# This script:
#   1. puts the tkn (0.46.2) and tkn-pac (0.52.0) command-line tools on the PATH,
#   2. applies the namespaces starfleet and gitea, Gitea and the tester pod,
#   3. installs Tekton Pipelines v1.17.1 and Pipelines-as-Code v0.52.0,
#   4. creates the Gitea user starfleet and an access token (Secret gitea/gitea-token),
#   5. seeds starfleet/bridge-app with .tekton/pull-request.yaml and .tekton/push.yaml,
#   6. connects it: Secret gitea-webhook-config, Repository bridge-app, Gitea webhook.
set -euo pipefail

TKN_VERSION="0.46.2"
PAC_CLI_VERSION="0.52.0"
PIPELINES_VERSION="v1.17.1"
PAC_VERSION="v0.52.0"
INSTALL_PAC="yes"   # yes or no
CREATE_CADET="no"   # yes or no: a second Gitea user without rights on the repository
LOG="[playground]"

GITEA_API="http://gitea-http.gitea:3000/api/v1"
OWNER="starfleet"
OWNER_PASSWORD="starfleet-password"   # lab-only credentials

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Pin the versions rather than accepting whatever tkn and tkn-pac happen to be
# on the machine: the course is written against tkn ${TKN_VERSION} and
# tkn-pac ${PAC_CLI_VERSION}.
have_version=""
if command -v tkn >/dev/null 2>&1; then
  have_version="$(tkn version --component client 2>/dev/null || true)"
  have_version="${have_version#v}"
fi
if [ "$have_version" != "$TKN_VERSION" ]; then
  case "$(uname -s)" in
    Darwin) TKN_OS="Darwin"; TKN_ARCH="all" ;;
    Linux)
      TKN_OS="Linux"
      case "$(uname -m)" in
        x86_64|amd64) TKN_ARCH="x86_64" ;;
        aarch64|arm64) TKN_ARCH="aarch64" ;;
        *) echo "ERROR: no tkn release for $(uname -m)." >&2; exit 1 ;;
      esac ;;
    *) echo "ERROR: no tkn release for $(uname -s)." >&2; exit 1 ;;
  esac
  echo "$LOG Downloading tkn ${TKN_VERSION} (${TKN_OS}/${TKN_ARCH})..."
  curl -fsSL -o "$WORK/tkn.tar.gz" \
    "https://github.com/tektoncd/cli/releases/download/v${TKN_VERSION}/tkn_${TKN_VERSION}_${TKN_OS}_${TKN_ARCH}.tar.gz"
  tar -xzf "$WORK/tkn.tar.gz" -C "$WORK" tkn
  install -m 0755 "$WORK/tkn" "$BIN_DIR/tkn"
fi
echo "$LOG tkn client version: $(tkn version --component client)"

# tkn-pac is the Pipelines-as-Code command-line tool. tkn finds every tkn-<name>
# program on the PATH, so `tkn pac` runs it as a plugin.
have_version=""
if command -v tkn-pac >/dev/null 2>&1; then
  have_version="$(tkn-pac version 2>/dev/null || true)"
  have_version="${have_version#v}"
fi
if [ "$have_version" != "$PAC_CLI_VERSION" ]; then
  case "$(uname -s)" in
    Darwin)
      PAC_ASSET="tkn-pac_${PAC_CLI_VERSION}_darwin_all.zip" ;;
    Linux)
      case "$(uname -m)" in
        x86_64|amd64) PAC_ASSET="tkn-pac_${PAC_CLI_VERSION}_linux_x86_64.tar.gz" ;;
        aarch64|arm64) PAC_ASSET="tkn-pac_${PAC_CLI_VERSION}_linux_arm64.tar.gz" ;;
        *) echo "ERROR: no tkn-pac release for $(uname -m)." >&2; exit 1 ;;
      esac ;;
    *) echo "ERROR: no tkn-pac release for $(uname -s)." >&2; exit 1 ;;
  esac
  echo "$LOG Downloading tkn-pac ${PAC_CLI_VERSION} (${PAC_ASSET})..."
  curl -fsSL -o "$WORK/$PAC_ASSET" \
    "https://github.com/tektoncd/pipelines-as-code/releases/download/v${PAC_CLI_VERSION}/${PAC_ASSET}"
  case "$PAC_ASSET" in
    *.zip) unzip -o -q "$WORK/$PAC_ASSET" tkn-pac -d "$WORK" ;;
    *) tar -xzf "$WORK/$PAC_ASSET" -C "$WORK" tkn-pac ;;
  esac
  install -m 0755 "$WORK/tkn-pac" "$BIN_DIR/tkn-pac"
fi
echo "$LOG tkn-pac version: $(tkn-pac version)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR=""
for candidate in "$SCRIPT_DIR/../manifests" "./manifests" "$SCRIPT_DIR/manifests"; do
  [ -d "$candidate" ] && { MANIFEST_DIR="$candidate"; break; }
done
[ -n "$MANIFEST_DIR" ] || { echo "ERROR: manifests folder not found." >&2; exit 1; }

apply_with_retry() {
  # apply_with_retry ARGS...: kubectl apply, retried while the API server or
  # an admission webhook is still starting.
  local attempt
  for attempt in $(seq 1 30); do
    if kubectl apply "$@"; then
      return 0
    fi
    echo "$LOG kubectl apply failed (attempt $attempt), retrying in 5s..."
    sleep 5
  done
  echo "ERROR: kubectl apply $* kept failing." >&2
  return 1
}

# lab-start.yaml is also listed under bootstrap.manifests in config.yaml, so it
# may already be applied. kubectl apply is idempotent.
apply_with_retry -f "$MANIFEST_DIR/lab-start.yaml"

wait_for_tekton_webhook() {
  # The Tekton webhook validates every Tekton object. A Deployment can be
  # Available a moment before its Service answers, so retry a server-side dry
  # run of a small Task until the webhook accepts it.
  local probe attempt
  probe="$(mktemp)"
  cat > "$probe" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: webhook-probe
  namespace: starfleet
spec:
  steps:
    - name: probe
      image: busybox:1.37.0
      script: |
        echo probe
YAML
  for attempt in $(seq 1 60); do
    if kubectl apply --dry-run=server -f "$probe" >/dev/null 2>&1; then
      rm -f "$probe"
      echo "$LOG The Tekton webhook answers."
      return 0
    fi
    sleep 5
  done
  rm -f "$probe"
  echo "ERROR: the Tekton webhook did not accept a Task within 5 minutes." >&2
  return 1
}

wait_for_pac_webhook() {
  # The Pipelines-as-Code webhook validates every Repository. It fills in its
  # own rules and certificate after it starts, so a dry run can pass before it
  # really answers. Wait until it rejects a Repository with an ftp:// URL:
  # only the webhook checks the URL scheme.
  local probe attempt output
  probe="$(mktemp)"
  cat > "$probe" <<'YAML'
apiVersion: pipelinesascode.tekton.dev/v1alpha1
kind: Repository
metadata:
  name: webhook-probe
  namespace: starfleet
spec:
  url: "ftp://example.com/probe/webhook-probe"
YAML
  for attempt in $(seq 1 60); do
    output="$(kubectl apply --dry-run=server -f "$probe" 2>&1 || true)"
    case "$output" in
      *"scheme must be http or https"*)
        rm -f "$probe"
        echo "$LOG The Pipelines-as-Code webhook answers."
        return 0 ;;
    esac
    sleep 5
  done
  rm -f "$probe"
  echo "ERROR: the Pipelines-as-Code webhook did not answer within 5 minutes." >&2
  return 1
}

echo "$LOG Installing Tekton Pipelines ${PIPELINES_VERSION}..."
apply_with_retry -f "https://infra.tekton.dev/tekton-releases/pipeline/previous/${PIPELINES_VERSION}/release.yaml"
for deployment in tekton-pipelines-controller tekton-pipelines-webhook tekton-events-controller; do
  kubectl -n tekton-pipelines rollout status "deployment/$deployment" --timeout=300s
done
kubectl -n tekton-pipelines-resolvers rollout status deployment/tekton-pipelines-remote-resolvers --timeout=300s
wait_for_tekton_webhook

if [ "$INSTALL_PAC" = "yes" ]; then
  echo "$LOG Installing Pipelines-as-Code ${PAC_VERSION}..."
  apply_with_retry -f "https://github.com/tektoncd/pipelines-as-code/releases/download/${PAC_VERSION}/release.k8s.yaml"
  for deployment in pipelines-as-code-controller pipelines-as-code-watcher pipelines-as-code-webhook; do
    kubectl -n pipelines-as-code rollout status "deployment/$deployment" --timeout=300s
  done
  wait_for_pac_webhook
fi

echo "$LOG Waiting for Gitea and the tester pod..."
kubectl -n gitea rollout status deployment/gitea --timeout=300s
kubectl -n gitea rollout status deployment/tester --timeout=300s
gitea_ready=false
for _ in $(seq 1 60); do
  health="$(kubectl -n gitea exec deploy/tester -- curl -fsS http://gitea-http.gitea:3000/api/healthz 2>/dev/null || true)"
  case "$health" in
    *'"status"'*'pass'*) gitea_ready=true; break ;;
  esac
  sleep 3
done
[ "$gitea_ready" = true ] || { echo "ERROR: Gitea did not report healthy." >&2; exit 1; }

create_gitea_user() {
  # create_gitea_user NAME PASSWORD EMAIL [--admin]: Gitea can refuse the first
  # commands while it finishes starting, so retry until the user exists.
  local name="$1" password="$2" email="$3" admin="${4:-}" users
  for _ in $(seq 1 30); do
    # shellcheck disable=SC2086
    if kubectl -n gitea exec deploy/gitea -- gitea admin user create \
      --username "$name" --password "$password" --email "$email" \
      $admin --must-change-password=false >/dev/null 2>&1; then
      return 0
    fi
    users="$(kubectl -n gitea exec deploy/gitea -- gitea admin user list 2>/dev/null || true)"
    users="$(printf '%s\n' "$users" | awk 'NR > 1 {print $2}')"
    if printf '%s\n' "$users" | grep -x "$name" >/dev/null; then
      return 0
    fi
    sleep 2
  done
  echo "ERROR: could not create the Gitea user $name." >&2
  return 1
}

echo "$LOG Creating the Gitea user ${OWNER}..."
create_gitea_user "$OWNER" "$OWNER_PASSWORD" "starfleet@example.com" --admin
if [ "$CREATE_CADET" = "yes" ]; then
  echo "$LOG Creating the Gitea user cadet..."
  create_gitea_user cadet cadet-password cadet@example.com
fi

# A personal access token for the owner, the credential Pipelines-as-Code uses
# for the Gitea API. It is stored once in the Secret gitea/gitea-token.
if ! kubectl -n gitea get secret gitea-token >/dev/null 2>&1; then
  echo "$LOG Creating a Gitea access token for ${OWNER}..."
  token_body="{\"name\":\"pipelines-as-code-$(date +%s)\",\"scopes\":[\"write:repository\",\"write:issue\",\"read:user\",\"read:organization\"]}"
  token="$(kubectl -n gitea exec deploy/tester -- sh -c \
    'curl -fsS -u "$1" -X POST -H "Content-Type: application/json" --data "$2" "$3" | jq -r ".sha1 // empty"' \
    _ "$OWNER:$OWNER_PASSWORD" "$token_body" "$GITEA_API/users/$OWNER/tokens")"
  [ -n "$token" ] || { echo "ERROR: Gitea did not return an access token." >&2; exit 1; }
  kubectl -n gitea create secret generic gitea-token --from-literal=token="$token"
fi


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
# The starting state of this playground.
# ---------------------------------------------------------------------------
ensure_repository
echo "[playground] Seeding main with the application and the .tekton folder..."
seed_tree "$MANIFEST_DIR/repo" main
echo "[playground] Connecting the repository to Pipelines-as-Code..."
connect_repository
echo "[playground] Ready. starfleet/bridge-app is connected; the next push or pull request runs a pipeline."
