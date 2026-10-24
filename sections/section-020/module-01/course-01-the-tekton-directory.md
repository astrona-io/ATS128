# The .tekton Directory And Dynamic Variables

A PipelineRun that tests a pull request must know which commit to test. That commit changes with every event, so it cannot be written into the file. Pipelines-as-Code solves this with dynamic variables: placeholders in the template that it fills in for each event. This part shows how the folder is read, what Pipelines-as-Code changes in a template, and how to check what it created.

## How Pipelines-as-Code reads the folder

When an event matches a `Repository`, the pipelines-as-code-controller reads the `.tekton` folder at the top of the repository through the Git provider's API. It reads the folder from the commit of the event: for a pull request, that is the head commit of the pull request's branch. A change to `.tekton` in a pull request is therefore tested by that same pull request. A `Repository` setting, `spec.settings.pipelinerun_provenance: default_branch`, makes Pipelines-as-Code read the folder from the default branch instead, so that a pull request cannot change its own pipeline.

Every `.yaml` file in the folder (and its subfolders) can hold Tekton objects: PipelineRuns, and Pipelines or Tasks that the PipelineRuns reference by name. Pipelines-as-Code puts each matching PipelineRun together with what it references into one self-contained PipelineRun, then creates it. Each PipelineRun needs a unique `metadata.name`. Pipelines-as-Code uses the name as `generateName`, so `pull-request` becomes `pull-request-x7k2p` in the cluster, and the original name stays in the label `pipelinesascode.tekton.dev/original-prname`.

## Dynamic variables

A dynamic variable is a placeholder written as `{{ name }}`. The controller replaces it with a value from the event before it creates the PipelineRun. The ones you use most often are these:

| Variable | Value |
| --- | --- |
| `{{ revision }}` | The full SHA of the commit of the event |
| `{{ repo_url }}` | The URL of the repository that has the `Repository` object |
| `{{ source_url }}` | The URL of the repository the change comes from; for a pull request from a fork, the fork. For a push, the same as `repo_url` |
| `{{ repo_owner }}`, `{{ repo_name }}` | The owner and the name of the repository |
| `{{ target_branch }}`, `{{ source_branch }}` | The branch the event targets, and the branch it comes from |
| `{{ event_type }}` | The event type the provider sent, such as `pull_request` or `push` |
| `{{ sender }}` | The user who caused the event |
| `{{ pull_request_number }}` | The number of the pull request |
| `{{ target_namespace }}` | The namespace of the `Repository`, where the run is created |
| `{{ git_auth_secret }}` | The name of a Secret that Pipelines-as-Code creates with the token, to clone private repositories |

The usual pattern puts the variables into the PipelineRun's parameters, and the Tasks use the parameters. A Tekton variable such as `$(params.revision)` is replaced later, by Tekton, when the run starts; a dynamic variable is replaced earlier, by Pipelines-as-Code, before the PipelineRun exists.

<!-- astrona:playground:renew -->

Look at the parameters of the pull request template in your playground. Define a helper that reads a file from the repository, then print the start of the file:

```sh
gitea_raw() {
  kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
    "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/raw/$1?ref=${2:-main}"
}
gitea_raw .tekton/pull-request.yaml | head -20
```

The parameters are `repo_url` with the value `"{{ source_url }}"` and `revision` with the value `"{{ revision }}"`. The first step of the Task clones `$(params.repo_url)`, checks out `$(params.revision)` and writes `git rev-parse HEAD` into the result `commit`. The value is quoted, because `{{` at the start of a value is not valid YAML before Pipelines-as-Code replaces it.

## See the variables at work

A push to `main` matches `.tekton/push.yaml`. Push a small change and look at the PipelineRun that Pipelines-as-Code creates. Define a helper that commits a file from your machine to a branch through the Gitea API (it creates the file, or updates it with the `sha` Gitea needs), and prints the new commit SHA:

```sh
gitea_put_file() {
  local branch="$1" file="$2" path="$3" message="$4" sha method body
  sha="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password "$1" | jq -r ".sha // empty"' \
    _ "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/contents/$path?ref=$branch")"
  body="{\"branch\":\"$branch\",\"message\":\"$message\",\"content\":\"$(base64 < "$file" | tr -d '\n')\""
  if [ -n "$sha" ]; then method=PUT; body="$body,\"sha\":\"$sha\"}"; else method=POST; body="$body}"; fi
  kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password -X "$1" -H "Content-Type: application/json" --data "$2" "$3" | jq -r ".commit.sha"' \
    _ "$method" "$body" "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/contents/$path"
}
printf 'Notes for the bridge team.\n' > notes.txt
gitea_put_file main notes.txt docs/notes.md "Add notes"
```

The last command prints the SHA of the new commit on `main`. Gitea sends a push webhook, and a PipelineRun `push-...` appears in `starfleet`. Read its parameters and, once it has finished, its result:

```sh
kubectl get pipelineruns -n starfleet -l pipelinesascode.tekton.dev/original-prname=push
RUN="$(kubectl get pipelineruns -n starfleet -l pipelinesascode.tekton.dev/original-prname=push -o jsonpath='{.items[0].metadata.name}')"
kubectl get pipelinerun "$RUN" -n starfleet -o jsonpath='{range .spec.params[*]}{.name}={.value}{"\n"}{end}{.status.results[0].value}{"\n"}'
```

`repo_url` is now `http://gitea-http.gitea.svc.cluster.local:3000/starfleet/bridge-app`, and `revision` is the SHA your commit printed. The result `commit` is the same SHA: the run tested exactly the pushed commit. The PipelineRun object in the cluster contains no `{{ }}` at all.

> [!TIP]
> **Check a template before you push it.** `tkn pac resolve -f .tekton/pull-request.yaml -p revision=main --no-secret` prints the PipelineRun that Pipelines-as-Code would create, with the variables you pass, without any Git event. Run it in a clone of the repository, so it can read the rest of the folder.

You now know what happens to a template: Pipelines-as-Code reads `.tekton` from the event's commit, fills in the dynamic variables, and creates a PipelineRun with a generated name. The open question is how it decides which templates to use for an event.

## Common pitfalls

> [!WARNING]
> - **Writing a fixed branch or commit into the template.** A `revision: main` tests `main`, not the pull request. Use `{{ revision }}`.
> - **Unquoted variables at the start of a value.** `value: {{ revision }}` is not valid YAML until it is replaced, and editors and linters complain. Quote it.
> - **Cloning `{{ repo_url }}` for pull requests from forks.** The fork's commit is in `{{ source_url }}`; for pull requests inside one repository, both are the same.
> - **Confusing the two kinds of variables.** `{{ ... }}` is filled by Pipelines-as-Code before the run; `$(params.x)` is filled by Tekton during the run.
