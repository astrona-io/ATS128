#!/usr/bin/env bash
# PASS when the Repository bridge-app in starfleet sets concurrency_limit to 1.
set -uo pipefail

NS="starfleet"
if ! kubectl -n "$NS" get repository bridge-app >/dev/null 2>&1; then
  echo "FAIL: Repository bridge-app does not exist in $NS."
  exit 1
fi
limit="$(kubectl -n "$NS" get repository bridge-app -o jsonpath='{.spec.concurrency_limit}')"
if [ "$limit" != "1" ]; then
  echo "FAIL: Repository bridge-app has spec.concurrency_limit '${limit:-not set}', expected 1."
  exit 1
fi

echo "PASS: Repository bridge-app allows one running PipelineRun at a time."
exit 0
