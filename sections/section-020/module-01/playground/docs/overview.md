# Overview: Write Pipelines In The .tekton Directory (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Pipelines-as-Code and a connected Gitea repository, so every push and pull request you make runs the pipelines in `.tekton`. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Tekton Pipelines v1.17.1** and **Pipelines-as-Code v0.52.0** (namespace `pipelines-as-code`).
- **Gitea 28.2.0** in the namespace `gitea` (`http://gitea-http.gitea.svc.cluster.local:3000`), with the user `starfleet` (password `starfleet-password`, lab-only credentials).
- The public repository `starfleet/bridge-app`, connected to Pipelines-as-Code: the Secret `gitea-webhook-config`, the `Repository` `bridge-app` in `starfleet`, and a Gitea webhook to the controller Service on port 8080.
- Two templates on `main`:

  | File | PipelineRun | Runs for |
  | --- | --- | --- |
  | `.tekton/pull-request.yaml` | `pull-request` | Pull requests into `main` (`max-keep-runs: "5"`) |
  | `.tekton/push.yaml` | `push` | Pushes to `main` (`max-keep-runs: "3"`) |

  Both clone the repository at `{{ revision }}`, return the result `commit` and run `app/status.sh`.
- A `tester` pod in the namespace `gitea` with `curl` and `jq`.
- `tkn` 0.46.2 and `tkn pac` 0.52.0 on your PATH.

## Helpers

Paste these once in each new terminal. `gitea_raw` prints one file of the repository from a branch. `gitea_send` sends a request with a JSON body to the Gitea API. `gitea_put_file` commits a file from your machine to a branch and prints the new commit SHA. `show_runs` lists the PipelineRuns with their template name, event type and commit.

```sh
gitea_raw() {
  kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
    "http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/raw/$1?ref=${2:-main}"
}
gitea_send() {
  kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
    -X "$1" -H 'Content-Type: application/json' --data "$3" "http://gitea-http.gitea:3000/api/v1$2"
}
gitea_put_file() {
  local branch="$1" file="$2" path="$3" message="$4" sha method body
  sha="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password "$1" | jq -r ".sha // empty"' \
    _ "http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/contents/$path?ref=$branch")"
  body="{\"branch\":\"$branch\",\"message\":\"$message\",\"content\":\"$(base64 < "$file" | tr -d '\n')\""
  if [ -n "$sha" ]; then method=PUT; body="$body,\"sha\":\"$sha\"}"; else method=POST; body="$body}"; fi
  kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password -X "$1" -H "Content-Type: application/json" --data "$2" "$3" | jq -r ".commit.sha"' \
    _ "$method" "$body" "http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/contents/$path"
}
show_runs() {
  kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/original-prname,pipelinesascode.tekton.dev/event-type,pipelinesascode.tekton.dev/sha
}
```

Use them like this: `gitea_raw .tekton/push.yaml`, `gitea_send POST /repos/starfleet/bridge-app/branches '{"new_branch_name":"release-1.0","old_branch_name":"main"}'`, `gitea_put_file main notes.txt docs/notes.md "Add notes"`, `show_runs`.

If you prefer `git`, run `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal and clone `http://localhost:3000/starfleet/bridge-app.git` with the user `starfleet`.

## Practice tasks

- Add a third template, `.tekton/release.yaml` with the name `release`, for tags that match `refs/tags/v*`. Create a tag through the API (`POST /repos/starfleet/bridge-app/tags` with `{"tag_name":"v1.5.0","target":"main"}`) and watch it run.
- Change `.tekton/push.yaml` to use `on-cel-expression` with `event == "push" && target_branch == "main"`, then add a wrong `on-target-branch` next to it and prove that the CEL expression still decides.
- Copy `.tekton/push.yaml` to `.tekton/push-copy.yaml` without renaming the PipelineRun, push a commit, and find the error in `kubectl get events -n starfleet` and the controller log. Delete the copy.
- Add `pipelinesascode.tekton.dev/on-path-change-ignore: "[docs/**]"` to the pull request template on a branch, and open two pull requests: one that changes only `docs/`, one that changes `app/`.
- Push five commits to `main` and count the `push` runs that `max-keep-runs` keeps.
- Run `tkn pac resolve -f pull-request.yaml -p revision=main --no-secret` on a downloaded copy of the template and read the result.
