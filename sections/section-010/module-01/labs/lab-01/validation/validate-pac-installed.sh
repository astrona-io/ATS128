#!/usr/bin/env bash
# PASS when Pipelines-as-Code v0.52.0 runs: the Deployments controller, watcher
# and webhook in pipelines-as-code are available with v0.52.0 images, and the
# ConfigMap pipelines-as-code-info reports version v0.52.0.
set -uo pipefail

for deployment in pipelines-as-code-controller pipelines-as-code-watcher pipelines-as-code-webhook; do
  available="$(kubectl -n pipelines-as-code get deployment "$deployment" \
    -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)"
  if [ "$available" != "True" ]; then
    echo "FAIL: Deployment $deployment in pipelines-as-code is not available (Available=${available:-missing})."
    exit 1
  fi
  image="$(kubectl -n pipelines-as-code get deployment "$deployment" -o jsonpath='{.spec.template.spec.containers[0].image}')"
  case "$image" in
    *:v0.52.0) ;;
    *) echo "FAIL: Deployment $deployment runs '$image', expected a v0.52.0 image."; exit 1 ;;
  esac
done

version="$(kubectl -n pipelines-as-code get configmap pipelines-as-code-info -o jsonpath='{.data.version}' 2>/dev/null)"
if [ "$version" != "v0.52.0" ]; then
  echo "FAIL: ConfigMap pipelines-as-code-info reports version '${version}', expected v0.52.0."
  exit 1
fi

echo "PASS: Pipelines-as-Code v0.52.0 runs (controller, watcher and webhook available)."
exit 0
