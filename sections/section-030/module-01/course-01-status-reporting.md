# How Pipelines-as-Code Reports Status

The author of a pull request works in the Git provider, not in the cluster. If the result of a run stays in a PipelineRun object, nobody sees it. Pipelines-as-Code therefore writes every run back to the provider, at the start and at the end. This part shows what that looks like on each provider, how a failure is reported, and how to read the same information from the cluster.

## What each provider shows

A commit status is a small record that a tool attaches to one commit in the Git provider: a state (`pending`, `success`, `failure`), a name (the context) and a short description. The name Pipelines-as-Code uses is the application name from the ConfigMap `pipelines-as-code`, `Pipelines as Code CI`, followed by the name of the template, so a run of `lint` reports as `Pipelines as Code CI / lint`. Each template of a pull request gets its own status, so a pull request with two templates shows two lines.

What else the provider shows depends on how Pipelines-as-Code is connected:

| Connection | Where the result shows |
| --- | --- |
| GitHub App | A check run in the pull request's **Checks** tab, with the duration and status of each task, a log snippet for a failed step, and a re-run button |
| GitHub webhook | A comment on the pull request (no Checks API without an App) |
| GitLab | A pipeline status on the merge request and a comment |
| Gitea and Forgejo | A commit status per template and a comment on the pull request with the tasks and their results |

For a push, there is no pull request to comment on, so Pipelines-as-Code writes only the commit status (or the check run on GitHub).

<!-- astrona:playground:renew -->

See it in your playground. Create a branch with a small change and open a pull request. Define a helper that commits a file to a branch through the Gitea API first:

```sh
gitea_put_file() {
  local branch="$1" file="$2" path="$3" message="$4" sha method body
  sha="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password "$1" | jq -r ".sha // empty"' \
    _ "http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/contents/$path?ref=$branch")"
  body="{\"branch\":\"$branch\",\"message\":\"$message\",\"content\":\"$(base64 < "$file" | tr -d '\n')\""
  if [ -n "$sha" ]; then method=PUT; body="$body,\"sha\":\"$sha\"}"; else method=POST; body="$body}"; fi
  kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password -X "$1" -H "Content-Type: application/json" --data "$2" "$3" | jq -r ".commit.sha"' \
    _ "$method" "$body" "http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/contents/$path"
}
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X POST -H 'Content-Type: application/json' \
  http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/branches --data '{"new_branch_name":"feature-status","old_branch_name":"main"}'
printf '1.7.0\n' > VERSION
gitea_put_file feature-status VERSION app/VERSION "Bump the version to 1.7.0"
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X POST -H 'Content-Type: application/json' \
  http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/pulls --data '{"head":"feature-status","base":"main","title":"Bump the version to 1.7.0"}'
```

Two PipelineRuns start, `lint-...` and `unit-test-...`, at the same time. While they run, read the statuses of the pull request's head commit, and read them again after about half a minute:

```sh
gitea_statuses() {
  kubectl -n gitea exec deploy/tester -- sh -c 'sha="$(curl -sS -u starfleet:starfleet-password http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/pulls/$1 | jq -r .head.sha)"; curl -sS -u starfleet:starfleet-password "http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/commits/$sha/statuses" | jq -r ".[] | \"\(.id) \(.context): \(.status) - \(.description)\""' _ "$1"
}
gitea_statuses 1
```

First you see `pending` lines with the description `CI has Started`, written by the controller when it created the runs. Later you see `success` lines with the description `Success`, written by the watcher when each run finished. Gitea keeps every status, so the list grows; the newest line per name (the highest `id`) is the current one.

## A failed run

A failed run reports `failure`, and the comment says which task failed. On a pull request, Pipelines-as-Code adds the last lines of the failed step's log (three lines by default, from `error-log-snippet` in the ConfigMap), and hides the values of Secrets used in the step. Break the status line on the branch, so that `unit-test` no longer finds the word `nominal`:

```sh
printf '#!/bin/sh\necho "bridge-app: shields offline"\n' > status.sh
gitea_put_file feature-status status.sh app/status.sh "Change the status line"
```

The new commit sends a `pull_request` event (an update), and both templates run again for the new head commit. `lint` succeeds; `unit-test` fails. Wait until both have finished, then look at the status and at the newest comment on the pull request:

```sh
gitea_statuses 1
kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/issues/1/comments | jq -r ".[-1].body"'
```

The newest `Pipelines as Code CI / unit-test` line has the state `failure`. The comment names the failed task and shows the end of its log, with the line `unexpected status line`.

## The same view from the cluster

The `tkn pac` plugin reads the runs of a `Repository` from the cluster, using the Pipelines-as-Code labels on the PipelineRuns:

```sh
tkn pac list -n starfleet
tkn pac describe bridge-app -n starfleet
tkn pac logs bridge-app -n starfleet -L
```

`tkn pac list` shows each `Repository` with the status of its newest run. `tkn pac describe` lists the recent runs with their commit, event and result, and prints the end of every task's log when the newest run failed. `tkn pac logs -L` prints the logs of the last run through `tkn`. When no run appears at all, look one level lower: Pipelines-as-Code writes Kubernetes events into the namespace of the `Repository` (`kubectl get events -n starfleet`), and the controller log explains every decision it makes.

You now know where a result shows up: commit statuses and a comment on Gitea, checks on a GitHub App, a comment on a GitHub webhook, and the `tkn pac` commands in the cluster. The open question is what happens when many runs want to start at once.

## Common pitfalls

> [!WARNING]
> - **Reading the oldest status.** Gitea keeps every status of a commit. The current one is the newest per name.
> - **Expecting a comment for a push.** There is no pull request to comment on; read the commit status.
> - **Looking for the Checks tab with a GitHub webhook.** Only a GitHub App writes check runs.
> - **Changing `application-name` and searching for the old status names.** The prefix of every status comes from that setting.
