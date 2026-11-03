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

# 1. Set pipelinerun_provenance to default_branch on the Repository.
kubectl apply -f "$SCRIPT_DIR/repository-bridge-app.yaml"

# 2. Ask for a new run of the head commit of pull request #1 with a comment.
#    The /retest command starts the pipelines again, and this time the
#    controller reads .tekton from main.
sha=""
for _ in $(seq 1 30); do
  sha="$(gitea_query "$OWNER_AUTH" "$REPO_PATH/branches/feature-tamper" '.commit.id')"
  [ -n "$sha" ] && break
  sleep 2
done
number="$(gitea_query "$OWNER_AUTH" "$REPO_PATH/pulls?state=open" '[.[] | select(.head.ref == "feature-tamper")][0].number')"
gitea_api "$OWNER_AUTH" POST "$REPO_PATH/issues/$number/comments" '{"body":"/retest"}' >/dev/null

# 3. Wait for a finished run of the head commit that is not the failed one.
for _ in $(seq 1 60); do
  newest="$(kubectl -n starfleet get pipelineruns \
    -l "pipelinesascode.tekton.dev/sha=$sha,pipelinesascode.tekton.dev/original-prname=pull-request" \
    --sort-by=.metadata.creationTimestamp \
    -o jsonpath='{.items[-1:].metadata.name}' 2>/dev/null || true)"
  if [ -n "$newest" ]; then
    condition="$(kubectl -n starfleet get pipelinerun "$newest" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}')"
    if [ "$condition" = "True" ]; then
      echo "[solution] PipelineRun $newest succeeded."
      exit 0
    fi
  fi
  sleep 5
done
echo "ERROR: no successful PipelineRun for $sha after /retest." >&2
exit 1
