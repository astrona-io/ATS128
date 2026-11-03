#!/usr/bin/env bash
# PASS when the Secret named by the incoming webhook exists in starfleet with
# the named key, has a non-empty value of at least 12 characters, and the
# value is not written in the Repository itself.
set -uo pipefail

NS="starfleet"

secret_name="$(kubectl -n "$NS" get repository bridge-app -o jsonpath='{.spec.incoming[0].secret.name}' 2>/dev/null)"
secret_key="$(kubectl -n "$NS" get repository bridge-app -o jsonpath='{.spec.incoming[0].secret.key}' 2>/dev/null)"
if [ -z "$secret_name" ] || [ -z "$secret_key" ]; then
  echo "FAIL: the incoming webhook of the Repository names no Secret."
  exit 1
fi
if ! kubectl -n "$NS" get secret "$secret_name" >/dev/null 2>&1; then
  echo "FAIL: the Secret '$secret_name' does not exist in $NS."
  exit 1
fi
value="$(kubectl -n "$NS" get secret "$secret_name" -o json | jq -r --arg key "$secret_key" '.data[$key] // empty' | base64 -d 2>/dev/null)"
if [ -z "$value" ]; then
  echo "FAIL: the Secret '$secret_name' has no key '$secret_key', or the value is empty."
  exit 1
fi
if [ "${#value}" -lt 12 ]; then
  echo "FAIL: the secret value has ${#value} characters, use at least 12."
  exit 1
fi
if kubectl -n "$NS" get repository bridge-app -o json | grep -F "$value" >/dev/null; then
  echo "FAIL: the secret value is written in the Repository. Keep it in the Secret only."
  exit 1
fi

echo "PASS: the Secret '$secret_name' holds the incoming webhook secret."
exit 0
