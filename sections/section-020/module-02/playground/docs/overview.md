# Overview: Parameters, Secrets, Remote Tasks And Resolving (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Pipelines-as-Code and a connected Gitea repository, so every push and pull request you make runs the pipelines in `.tekton`. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Tekton Pipelines v1.17.1** and **Pipelines-as-Code v0.52.0** (namespace `pipelines-as-code`).
- **Gitea 28.2.0** in the namespace `gitea` (`http://gitea-http.gitea.svc.cluster.local:3000`), with the user `starfleet` (password `starfleet-password`, lab-only credentials).
- The public repository `starfleet/bridge-app`, connected to Pipelines-as-Code: the Secret `gitea-webhook-config`, the `Repository` `bridge-app` in `starfleet`, and a Gitea webhook to the controller Service on port 8080.
- Two templates on `main`: `.tekton/pull-request.yaml` (the PipelineRun `pull-request`, for pull requests into `main`) and `.tekton/push.yaml` (the PipelineRun `push`, for pushes to `main`). Both clone the repository at `{{ revision }}`, return the result `commit` and run `app/status.sh`.
- A `tester` pod in the namespace `gitea` with `curl` and `jq`.
- `tkn` 0.46.2 and `tkn pac` 0.52.0 on your PATH.

## Helpers

Paste these once in each new terminal. `gitea_raw` prints one file of the repository from a branch. `gitea_send` sends a request with a JSON body to the Gitea API. `gitea_put_file` commits a file from your machine to a branch and prints the new commit SHA. `show_runs` lists the PipelineRuns with their template name, event type and commit.

```sh
gitea_raw() {
  kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
    "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/raw/$1?ref=${2:-main}"
}
gitea_send() {
  kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
    -X "$1" -H 'Content-Type: application/json' --data "$3" "http://gitea-http.gitea.svc.cluster.local:3000/api/v1$2"
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
show_runs() {
  kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/original-prname,pipelinesascode.tekton.dev/event-type,pipelinesascode.tekton.dev/sha
}
```

Use them like this: `gitea_raw .tekton/push.yaml`, `gitea_send POST /repos/starfleet/bridge-app/branches '{"new_branch_name":"release-1.0","old_branch_name":"main"}'`, `gitea_put_file main notes.txt docs/notes.md "Add notes"`, `show_runs`.

If you prefer `git`, run `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal and clone `http://localhost:3000/starfleet/bridge-app.git` with the user `starfleet`.

## Practice tasks

- Add `params` with a name and a value to the `Repository`, use `{{ name }}` in `.tekton/push.yaml` and read the value in the PipelineRun with `kubectl get pipelinerun -o yaml`.
- Add a param with a `filter` expression and push to `main` and open a pull request to see when it has a value.
- Print the dynamic variables of an event with a step that echoes `{{ event_type }}`, `{{ target_branch }}`, `{{ source_branch }}` and `{{ sender }}`.
- Create a Secret in `starfleet` and a param with `secret_ref`, and print the length of the value in a step, never the value.
- Put a Task file in `.tekton/` and reference it with `taskRef` in a PipelineRun, then change its name so the reference breaks and read the error.
- Resolve a template on your machine with `tkn pac resolve -f pull-request.yaml -p revision=main --no-secret`.
