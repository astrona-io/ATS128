# CEL Expressions, Path Changes And Cleanup

An event and a branch are not always enough. A team may want to skip the push pipeline when a commit only changes the documentation, or to run a pipeline for every branch except one. Pipelines-as-Code has two tools for this: CEL expressions and path matching. This part covers both, then two things that decide whether a well-matched PipelineRun really runs and how long it stays: duplicate names, remote tasks, and the cleanup of old runs.

## CEL expressions

The Common Expression Language (CEL) is a small expression language that evaluates to true or false. The annotation `pipelinesascode.tekton.dev/on-cel-expression` holds one expression, and the PipelineRun runs when it is true. The expression can use these fields: `event` (`push`, `pull_request` or `incoming`), `event_type`, `target_branch`, `source_branch`, `target_url`, `source_url`, `event_title`, `body` and `headers` (the raw webhook), `files` (the changed files), and the parameters of the `Repository`. For a push, `target_branch` holds the short branch name, such as `main`, unless the expression itself contains `refs/heads/`.

```yaml
pipelinesascode.tekton.dev/on-cel-expression: |
  event == "pull_request" && target_branch != "experimental" && source_branch.matches(".*feat/.*")
```

One rule matters more than any other: **a CEL expression overrides the other matching annotations.** When a PipelineRun has `on-cel-expression`, Pipelines-as-Code ignores its `on-event`, `on-target-branch`, `on-label`, `on-path-change` and `on-path-change-ignore`. A template with a correct `on-target-branch` and a wrong CEL expression never runs, and the correct annotation is no help. Keep one way of matching per PipelineRun.

## Path changes

Path matching runs a PipelineRun only when certain files change. There are two ways to write it. The annotations `pipelinesascode.tekton.dev/on-path-change` and `pipelinesascode.tekton.dev/on-path-change-ignore` take a list of globs and work together with `on-event` and `on-target-branch`:

```yaml
pipelinesascode.tekton.dev/on-event: "[push]"
pipelinesascode.tekton.dev/on-target-branch: "[main]"
pipelinesascode.tekton.dev/on-path-change: "[app/**]"
```

Inside a CEL expression, a glob string with `.pathChanged()` does the same, and `files.all`, `files.added`, `files.modified`, `files.deleted` and `files.renamed` give the lists themselves. Pipelines-as-Code gets the changed files from the provider: for a pull request, every file of the pull request; for a push, the files of the pushed commits.

<!-- astrona:playground:renew -->

Check the glob first, then change `.tekton/push.yaml` on `main` so that it runs only when something under `app/` changes. A pattern that works on a string is easy to test:

```sh
tkn pac info globbing -s "app/VERSION" "app/**"
tkn pac info globbing -s "docs/notes.md" "app/**"
```

The first pattern matches, the second does not. Now fetch the push template, add the path annotation, and commit it with the same `gitea_put_file` helper that commits a file through the Gitea API:

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
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/raw/.tekton/push.yaml?ref=main" > push.yaml
awk '{print} /on-target-branch: "\[main\]"/ {print "    pipelinesascode.tekton.dev/on-path-change: \"[app/**]\""}' push.yaml > push-paths.yaml
grep -n "pipelinesascode" push-paths.yaml
gitea_put_file main push-paths.yaml .tekton/push.yaml "Run the push pipeline only for application changes"
```

`grep` shows the new `on-path-change` line under `on-target-branch`. The commit itself changes only `.tekton/push.yaml`, which is not under `app/`, so it starts no push run. Now push one change outside and one inside `app/`, and compare:

```sh
printf 'More notes.\n' > notes.txt
gitea_put_file main notes.txt docs/more-notes.md "Add more notes"
printf '1.4.1\n' > VERSION
gitea_put_file main VERSION app/VERSION "Release 1.4.1"
kubectl get pipelineruns -n starfleet -l pipelinesascode.tekton.dev/original-prname=push -L pipelinesascode.tekton.dev/sha
```

Only the commit that changed `app/VERSION` has a new `push` run. The path rule depends on the list of changed files that Gitea sends with a push; if no run appears for the `app/` commit either, read the controller log for the matching decision.

## Names, remote tasks and cleanup

Three more rules decide what happens to a PipelineRun that matches. First, names must be unique. If two files in `.tekton` define PipelineRuns with the same `metadata.name`, Pipelines-as-Code stops with the error "found multiple pipelinerun in .tekton with the same name" and runs **nothing** for the event, not even the other, correct PipelineRuns. A copied file that was not renamed is the usual cause.

Second, a PipelineRun can use Tasks and Pipelines from outside the repository. The annotation `pipelinesascode.tekton.dev/task: "[git-clone]"` fetches the Task `git-clone` from Artifact Hub (the `hub-url` in the ConfigMap `pipelines-as-code`), and the annotation `pipelinesascode.tekton.dev/pipeline` does the same for a Pipeline; both also accept an HTTP URL or a path in the repository. Pipelines-as-Code puts the fetched objects into the PipelineRun before it creates it. Your playground's templates use inline `taskSpec` instead, so they need no internet.

Third, runs pile up. Every event creates a new PipelineRun, and Tekton keeps them until somebody deletes them. The annotation `pipelinesascode.tekton.dev/max-keep-runs: "3"` tells the pipelines-as-code-watcher to keep the three newest finished runs of this template after each successful run, and delete older ones. It counts runs of the same `Repository` with the same original name, and it skips runs that are still running or pending. The ConfigMap `pipelines-as-code` has a default for all repositories (`default-max-keep-runs`) and an upper limit (`max-keep-run-upper-limit`).

```sh
kubectl get pipelinerun -n starfleet -l pipelinesascode.tekton.dev/original-prname=push \
  -o jsonpath='{range .items[*]}{.metadata.name} {.metadata.annotations.pipelinesascode\.tekton\.dev/max-keep-runs}{"\n"}{end}'
```

Each `push` run shows `3`, the value copied from the template. Push more than three `app/` changes and the list never grows past three finished runs.

You now have the full set of matching tools: events and branches, CEL expressions that override them, path rules, and the cleanup of old runs. The rule to remember is that one wrong detail (a misspelled event, a CEL expression for the wrong branch, a duplicate name) silently stops a run.

## Common pitfalls

> [!WARNING]
> - **A CEL expression next to `on-event` and `on-target-branch`.** The CEL expression wins; the other annotations are ignored.
> - **A duplicate `metadata.name` in `.tekton`.** Nothing runs for the event. Give every PipelineRun its own name.
> - **Expecting the commit that adds a path rule to run.** It changes only `.tekton`, so it may not match its own rule.
> - **`max-keep-runs` and running pipelines.** Cleanup happens after a successful run and keeps runs that are still running or pending.
> - **Remote tasks in an offline cluster.** `pipelinesascode.tekton.dev/task` fetches from Artifact Hub or a URL; without network access, the run fails before it starts.
