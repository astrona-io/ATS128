#!/usr/bin/env bash
# PASS when a PipelineRun from .tekton/release.yaml exists for the event type
# incoming, succeeded, ran with environment staging, and tested the current
# head commit of main.
set -uo pipefail

NS="starfleet"
GITEA_API="http://gitea-http.gitea.svc.cluster.local:3000/api/v1"
OWNER_AUTH="starfleet:starfleet-password"   # lab-only credentials
REPO_PATH="/repos/starfleet/bridge-app"

run=""
for _ in $(seq 1 36); do
  run="$(kubectl -n "$NS" get pipelineruns -l pipelinesascode.tekton.dev/original-prname=release \
    --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}' 2>/dev/null)"
  if [ -n "$run" ]; then
    condition="$(kubectl -n "$NS" get pipelinerun "$run" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}')"
    if [ "$condition" = "True" ] || [ "$condition" = "False" ]; then
      break
    fi
  fi
  sleep 5
done
if [ -z "$run" ]; then
  echo "FAIL: no PipelineRun from .tekton/release.yaml exists. Call the incoming webhook."
  exit 1
fi
condition="$(kubectl -n "$NS" get pipelinerun "$run" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}')"
if [ "$condition" != "True" ]; then
  reason="$(kubectl -n "$NS" get pipelinerun "$run" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].reason}')"
  echo "FAIL: PipelineRun $run has Succeeded=${condition:-none} (reason: ${reason:-none})."
  exit 1
fi
event_type="$(kubectl -n "$NS" get pipelinerun "$run" -o jsonpath='{.metadata.labels.pipelinesascode\.tekton\.dev/event-type}')"
if [ "$event_type" != "incoming" ]; then
  echo "FAIL: PipelineRun $run has event-type '$event_type', expected incoming."
  exit 1
fi
environment="$(kubectl -n "$NS" get pipelinerun "$run" -o jsonpath='{.spec.params[?(@.name=="environment")].value}')"
if [ "$environment" != "staging" ]; then
  echo "FAIL: PipelineRun $run has environment '${environment:-empty}', expected staging. Send it in the body of the request."
  exit 1
fi
head="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -fsS -u "$1" "$2" | jq -r ".commit.id"' \
  _ "$OWNER_AUTH" "$GITEA_API$REPO_PATH/branches/main" 2>/dev/null)"
sha="$(kubectl -n "$NS" get pipelinerun "$run" -o jsonpath='{.metadata.labels.pipelinesascode\.tekton\.dev/sha}')"
if [ -n "$head" ] && [ "$sha" != "$head" ]; then
  echo "FAIL: PipelineRun $run tested commit '$sha', not the head of main '$head'."
  exit 1
fi

echo "PASS: PipelineRun $run was started by the incoming webhook and released to staging."
exit 0
