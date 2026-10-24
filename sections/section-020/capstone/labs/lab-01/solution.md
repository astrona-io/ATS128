# Solution: Route Push Pipelines By Branch

Work the task yourself first. Running `astrona submit -c sections/section-020/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the `.tekton` folder on `main` (unique names, one `push` with `max-keep-runs: "3"`, `pull-request` kept); the routing, with its own commits to `feature-engines`, `main` and `release-1.0`; and the cleanup after at least four pushes.

## Step 1: Read the .tekton folder

List the files and print each one:

```sh
kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/contents/.tekton?ref=main" | jq -r ".[].path"'
for file in push.yaml push-copy.yaml; do
  kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
    "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/raw/.tekton/$file?ref=main" | sed -n '1,14p'
done
```

There are three files: `pull-request.yaml`, `push.yaml` and `push-copy.yaml`. Two faults stop every push run:

- `push-copy.yaml` is an old copy that also names its PipelineRun `push`. With two PipelineRuns of the same name, Pipelines-as-Code stops with "found multiple pipelinerun in .tekton with the same name" and runs nothing for the event. The controller log and `kubectl get events -n starfleet` show this after any push.
- `push.yaml` has `on-cel-expression: event == "push" && target_branch == "release"`. A CEL expression overrides `on-event` and `on-target-branch`, so the correct-looking `[main]` next to it does nothing, and the expression is true only for a branch named exactly `release`.

`push.yaml` also has no `max-keep-runs`.

## Step 2: Delete the copy

Deleting a file through the Gitea API needs its blob `sha`:

```sh
FILE_SHA="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/contents/.tekton/push-copy.yaml?ref=main" | jq -r .sha')"
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X DELETE -H 'Content-Type: application/json' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/contents/.tekton/push-copy.yaml \
  --data "{\"branch\":\"main\",\"message\":\"Remove the old copy of the push pipeline\",\"sha\":\"$FILE_SHA\"}"
```

## Step 3: Fix push.yaml

Remove the CEL expression, match `main` and every `release-*` branch with a glob, and keep three runs.

Save this as `push.yaml`:

```yaml
# Pipelines-as-Code runs this PipelineRun for every push to main or to a
# release-* branch, and keeps the three newest finished runs.
# The values of the parameters below are dynamic variables (repo_url and
# revision): Pipelines-as-Code replaces them with the repository URL and the pushed commit SHA.
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: push
  annotations:
    pipelinesascode.tekton.dev/on-event: "[push]"
    pipelinesascode.tekton.dev/on-target-branch: "[main, release-*]"
    pipelinesascode.tekton.dev/max-keep-runs: "3"
spec:
  params:
    - name: repo_url
      value: "{{ repo_url }}"
    - name: revision
      value: "{{ revision }}"
  pipelineSpec:
    params:
      - name: repo_url
        type: string
      - name: revision
        type: string
    results:
      - name: commit
        value: $(tasks.checkout-and-test.results.commit)
    tasks:
      - name: checkout-and-test
        params:
          - name: repo_url
            value: $(params.repo_url)
          - name: revision
            value: $(params.revision)
        taskSpec:
          params:
            - name: repo_url
              type: string
            - name: revision
              type: string
          results:
            - name: commit
              description: The commit SHA that was checked out
          steps:
            - name: clone
              image: alpine/git:v2.52.0
              workingDir: /workspace
              script: |
                #!/bin/sh
                set -eu
                # The workspace folder belongs to another user than this step, so git
                # must be told that the clone is safe to use.
                git config --global --add safe.directory /workspace/source
                git clone --quiet "$(params.repo_url)" source
                cd source
                git checkout --quiet "$(params.revision)"
                git rev-parse HEAD | tr -d '\n' > "$(results.commit.path)"
                echo "Checked out $(params.revision)"
            - name: test
              image: busybox:1.37.0
              workingDir: /workspace/source
              script: |
                #!/bin/sh
                set -eu
                sh app/status.sh
```

Commit it to `main` with PUT and the file's `sha`:

```sh
FILE_SHA="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/contents/.tekton/push.yaml?ref=main" | jq -r .sha')"
CONTENT="$(base64 < push.yaml | tr -d '\n')"
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X PUT -H 'Content-Type: application/json' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/contents/.tekton/push.yaml \
  --data "{\"branch\":\"main\",\"message\":\"Run the push pipeline for main and release branches\",\"sha\":\"$FILE_SHA\",\"content\":\"$CONTENT\"}"
```

This commit is itself a push to `main`, read with the fixed `.tekton`, so it starts the first `push` run:

```sh
kubectl get pipelineruns -n starfleet -l pipelinesascode.tekton.dev/original-prname=push -L pipelinesascode.tekton.dev/sha
```

A different, correct answer is to keep a CEL expression, for example `event == "push" && (target_branch == "main" || target_branch.startsWith("release-"))`, without the other two annotations. The grader checks the behaviour, not the style.

## Step 4: Submit

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

The grader commits to `feature-engines`, `main` and `release-1.0`, waits for the runs and the statuses, then pushes to `main` until at least four `push` runs have existed and counts the kept ones.

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Fix `on-target-branch` and keep the CEL expression | The CEL expression still decides; nothing runs for `main` |
| Rename `push-copy.yaml` to another file name | The PipelineRun inside is still called `push`; the duplicate stays |
| `on-target-branch: "[refs/heads/*]"` | Feature branches run too; the grader's commit on `feature-engines` must start nothing |
| `release.*` as the pattern | Globs are not regular expressions; use `release-*` |

## Common mistakes

- Reading only `push.yaml`. The duplicate in another file stops the run just as well.
- Checking the first commit after the fix and finding no run for the commit that deleted the copy. That commit still had the CEL expression.
- Setting `max-keep-runs: 3` without quotes. Annotation values must be strings; Pipelines-as-Code cannot read a template with a number there.

## Practice on your own

- Create a branch `release-2.0` and push to it; then push to `feature-engines` and compare with `tkn pac list -n starfleet`.
- Push four commits to `main` quickly and watch the watcher delete the oldest `push` runs once each run succeeds.
