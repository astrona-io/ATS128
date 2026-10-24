#!/usr/bin/env bash
# Runs before the reference solution is applied.
#
# `astrona test` bootstraps and applies in one go. Wait until every Tekton and
# Pipelines-as-Code Deployment that should run is Available and Gitea answers,
# so the reference solution never races a component that is still starting.
set -euo pipefail

for namespace in tekton-pipelines tekton-pipelines-resolvers pipelines-as-code; do
  deployments="$(kubectl -n "$namespace" get deployment -o name 2>/dev/null || true)"
  for deployment in $deployments; do
    replicas="$(kubectl -n "$namespace" get "$deployment" -o jsonpath='{.spec.replicas}')"
    [ "$replicas" = "0" ] && continue
    kubectl -n "$namespace" rollout status "$deployment" --timeout=300s
  done
done
kubectl -n gitea rollout status deployment/gitea --timeout=300s
kubectl -n gitea rollout status deployment/tester --timeout=300s
for _ in $(seq 1 60); do
  health="$(kubectl -n gitea exec deploy/tester -- curl -fsS http://gitea-http.gitea.svc.cluster.local:3000/api/healthz 2>/dev/null || true)"
  case "$health" in
    *'"status"'*'pass'*) echo "[test] Tekton, Pipelines-as-Code and Gitea are ready."; exit 0 ;;
  esac
  sleep 3
done
echo "ERROR: Gitea did not report healthy." >&2
exit 1
