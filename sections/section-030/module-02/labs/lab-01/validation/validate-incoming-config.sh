#!/usr/bin/env bash
# PASS when the Repository bridge-app has one incoming webhook of the type
# webhook-url that targets main, lists the param environment and reads its
# secret from a Secret that exists.
set -uo pipefail

NS="starfleet"

incoming_count="$(kubectl -n "$NS" get repository bridge-app -o jsonpath='{.spec.incoming[*].type}' 2>/dev/null | wc -w | tr -d ' ')"
if [ "$incoming_count" = "0" ]; then
  echo "FAIL: the Repository bridge-app has no spec.incoming entry."
  exit 1
fi
type="$(kubectl -n "$NS" get repository bridge-app -o jsonpath='{.spec.incoming[0].type}')"
if [ "$type" != "webhook-url" ]; then
  echo "FAIL: spec.incoming[0].type is '$type', expected webhook-url."
  exit 1
fi
targets="$(kubectl -n "$NS" get repository bridge-app -o jsonpath='{.spec.incoming[0].targets[*]}')"
case " $targets " in
  *" main "*) ;;
  *) echo "FAIL: spec.incoming[0].targets is '${targets:-empty}', it must list main."; exit 1 ;;
esac
params="$(kubectl -n "$NS" get repository bridge-app -o jsonpath='{.spec.incoming[0].params[*]}')"
case " $params " in
  *" environment "*) ;;
  *) echo "FAIL: spec.incoming[0].params is '${params:-empty}', it must list environment so that the caller can set it."; exit 1 ;;
esac
secret_name="$(kubectl -n "$NS" get repository bridge-app -o jsonpath='{.spec.incoming[0].secret.name}')"
secret_key="$(kubectl -n "$NS" get repository bridge-app -o jsonpath='{.spec.incoming[0].secret.key}')"
if [ -z "$secret_name" ] || [ -z "$secret_key" ]; then
  echo "FAIL: spec.incoming[0].secret needs a name and a key."
  exit 1
fi
count="$(kubectl -n "$NS" get repository -o name 2>/dev/null | grep -c .)"
if [ "$count" != "1" ]; then
  echo "FAIL: expected exactly one Repository in $NS, found $count."
  exit 1
fi

echo "PASS: the Repository bridge-app has an incoming webhook for main with the param environment."
exit 0
