# Overview: Control How Pipeline Runs Report, Queue And Start (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Pipelines-as-Code and a connected Gitea repository that has two pull request pipelines, plus a second Gitea user without rights. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Tekton Pipelines v1.17.1** and **Pipelines-as-Code v0.52.0** (namespace `pipelines-as-code`).
- **Gitea 28.2.0** in the namespace `gitea`, with two users (lab-only credentials):

  | User | Password | Rights on `starfleet/bridge-app` |
  | --- | --- | --- |
  | `starfleet` | `starfleet-password` | Owner (and Gitea administrator) |
  | `cadet` | `cadet-password` | None; can fork the public repository |

- The repository `starfleet/bridge-app`, connected to Pipelines-as-Code (`Repository` `bridge-app` in `starfleet`, no `concurrency_limit`), with two templates on `main`: `.tekton/lint.yaml` (`lint`) and `.tekton/unit-test.yaml` (`unit-test`). Both run for pull requests into `main` and take about 20 seconds.
- A `tester` pod in the namespace `gitea` with `curl` and `jq`.
- `tkn` 0.46.2 and `tkn pac` 0.52.0 on your PATH.

## Helpers

Paste these once in each new terminal. `gitea_as` sends a request with a JSON body to the Gitea API as one user. `gitea_put_file` commits a file from your machine to a branch of `starfleet/bridge-app`. `gitea_statuses` prints the commit statuses of a pull request's head commit. `show_runs` lists the PipelineRuns with their template, state and times.

```sh
gitea_as() {
  kubectl -n gitea exec deploy/tester -- curl -sS -u "$1:$1-password" \
    -X "$2" -H 'Content-Type: application/json' --data "$4" "http://gitea-http.gitea.svc.cluster.local:3000/api/v1$3"
}
gitea_put_file() {
  local branch="$1" file="$2" path="$3" message="$4" sha method body
  sha="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password "$1" | jq -r ".sha // empty"' \
    _ "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/contents/$path?ref=$branch")"
  body="{\"branch\":\"$branch\",\"message\":\"$message\",\"content\":\"$(base64 < "$file" | tr -d '\n')\""
  if [ -n "$sha" ]; then method=PUT; body="$body,\"sha\":\"$sha\"}"; else method=POST; body="$body}"; fi
  kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password -X "$1" -H "Content-Type: application/json" --data "$2" "$3" | jq -r ".commit.sha"' \
    _ "$method" "$body" "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/contents/$path"
}
gitea_statuses() {
  kubectl -n gitea exec deploy/tester -- sh -c 'sha="$(curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/pulls/$1 | jq -r .head.sha)"; curl -sS -u starfleet:starfleet-password "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/commits/$sha/statuses" | jq -r ".[] | \"\(.id) \(.context): \(.status) - \(.description)\""' _ "$1"
}
show_runs() {
  kubectl get pipelineruns -n starfleet --sort-by=.metadata.creationTimestamp \
    -o custom-columns=NAME:.metadata.name,TEMPLATE:.metadata.labels.pipelinesascode\\.tekton\\.dev/original-prname,STATE:.metadata.labels.pipelinesascode\\.tekton\\.dev/state,START:.status.startTime,DONE:.status.completionTime
}
```

Use them like this: `gitea_as starfleet POST /repos/starfleet/bridge-app/branches '{"new_branch_name":"feature-x","old_branch_name":"main"}'`, `gitea_put_file feature-x notes.txt docs/x.md "Add x"`, `gitea_statuses 1`, `show_runs`.

## Practice tasks

- Open a pull request with two pipelines and no limit, then set `concurrency_limit: 1` and push a commit to it. Compare the `START` and `DONE` times of both pairs of runs with `show_runs`.
- Set `concurrency_limit: 2` and push three commits quickly. How many runs are `started` at the same time, and which are `queued`?
- Try `concurrency_limit: 0` and read the error of the admission webhook.
- Make `unit-test` fail on a branch, then comment `/retest` and `/test lint` as `starfleet`, and count the new runs of each template.
- As `cadet`, fork the repository and open a pull request. Comment `/ok-to-test` as `cadet` (nothing happens), then as `starfleet`.
- Add `cadet` to an `OWNERS` file on `main`, push a new commit to the fork's branch, and see it run without approval.
- Add `pipelinesascode.tekton.dev/cancel-in-progress: "true"` to `lint` (with no concurrency limit) and push two commits to a pull request within a few seconds.
