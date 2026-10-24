#!/usr/bin/env bash
# Installs the environment for ats-128-capstone-020.
#
# Graded lab bootstrap: this prepares the environment ONLY. It never fixes the
# seeded faults.
# This script:
#   1. puts the tkn (0.46.2) and tkn-pac (0.52.0) command-line tools on the PATH,
#   2. applies the namespaces starfleet and gitea, Gitea and the tester pod,
#   3. installs Tekton Pipelines v1.17.1 and Pipelines-as-Code v0.52.0 and waits for their webhooks,
#   4. creates the Gitea user starfleet and an access token (Secret gitea/gitea-token).
set -euo pipefail

TKN_VERSION="0.46.2"
PAC_CLI_VERSION="0.52.0"
PIPELINES_VERSION="v1.17.1"
PAC_VERSION="v0.52.0"
INSTALL_PAC="yes"   # yes or no
CREATE_CADET="no"   # yes or no: a second Gitea user without rights on the repository
LOG="[lab]"

GITEA_API="http://gitea-http.gitea.svc.cluster.local:3000/api/v1"
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
  health="$(kubectl -n gitea exec deploy/tester -- curl -fsS http://gitea-http.gitea.svc.cluster.local:3000/api/healthz 2>/dev/null || true)"
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

echo "$LOG Environment installed."
kubectl get pods -n tekton-pipelines 2>/dev/null || true
kubectl get pods -n pipelines-as-code 2>/dev/null || true
