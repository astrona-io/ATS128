#!/usr/bin/env bash
# PASS when starfleet/bridge-app has an active Gitea webhook that sends push
# and pull request events to the Pipelines-as-Code controller Service on port 8080.
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

hooks="$(gitea_query "$OWNER_AUTH" "$REPO_PATH/hooks" \
  '.[] | select(.active == true) | "\(.type) \(.config.url) \(.events | join(","))"')"
if [ -z "$hooks" ]; then
  echo "FAIL: starfleet/bridge-app has no active webhook."
  exit 1
fi

found=""
while read -r type url events; do
  [ -n "$type" ] || continue
  if ! printf '%s\n' "${url%/}" | grep -Ex 'http://pipelines-as-code-controller\.pipelines-as-code(\.svc(\.cluster\.local)?)?:8080' >/dev/null; then
    continue
  fi
  if [ "$type" != "gitea" ]; then
    echo "FAIL: the webhook to $url has type '$type'; Pipelines-as-Code needs the Gitea type (signature header X-Gitea-Signature)."
    exit 1
  fi
  case ",$events," in
    *,pull_request*) found="$url" ;;
    *) echo "FAIL: the webhook to $url does not send pull request events (events: $events)."; exit 1 ;;
  esac
done <<< "$hooks"

if [ -z "$found" ]; then
  echo "FAIL: no active webhook targets http://pipelines-as-code-controller.pipelines-as-code.svc.cluster.local:8080 (found: $(printf '%s' "$hooks" | awk '{print $2}' | tr '\n' ' '))."
  exit 1
fi

echo "PASS: an active Gitea webhook sends pull request events to $found."
exit 0
