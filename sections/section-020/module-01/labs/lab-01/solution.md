# Solution: Fix The Event Matching Of A Pull Request Pipeline

Work the task yourself first. Running `astrona submit -c sections/section-020/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the template on `feature-shields` (name, `pull_request`, `main`, dynamic variables); a successful PipelineRun for the current head of pull request #1 whose result `commit` is that head; and the commit status `success`.

## Step 1: Read the template on the pull request branch

Pipelines-as-Code reads `.tekton` from the pull request's branch, so read it from `feature-shields`:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/raw/.tekton/pull-request.yaml?ref=feature-shields" > pull-request.yaml
grep -n 'on-event\|on-target-branch\|value:' pull-request.yaml
```

There are three faults:

- `on-event: "[pull-request]"`: the event is `pull_request`, with an underscore. No event ever matches this.
- `on-target-branch: "[master]"`: the pull request targets `main`.
- The parameter `revision` has the value `"main"`. Even with the matching fixed, every run would test `main` instead of the pull request.

## Step 2: Fix the template

Save this as `pull-request.yaml` (the whole file, with the three lines fixed):

```yaml
# Pipelines-as-Code runs this PipelineRun for every pull request into main.
# The values of the parameters below are dynamic variables (source_url and
# revision): Pipelines-as-Code replaces them with the pull request's repository URL and commit SHA.
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: pull-request
  annotations:
    pipelinesascode.tekton.dev/on-event: "[pull_request]"
    pipelinesascode.tekton.dev/on-target-branch: "[main]"
    pipelinesascode.tekton.dev/max-keep-runs: "5"
spec:
  params:
    - name: repo_url
      value: "{{ source_url }}"
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

## Step 3: Commit the fix to feature-shields

An existing file needs its blob `sha` for an update (Gitea answers `422` to a POST on an existing file). Read the `sha`, then send the new content with PUT:

```sh
FILE_SHA="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/contents/.tekton/pull-request.yaml?ref=feature-shields" | jq -r .sha')"
CONTENT="$(base64 < pull-request.yaml | tr -d '\n')"
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X PUT -H 'Content-Type: application/json' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/contents/.tekton/pull-request.yaml \
  --data "{\"branch\":\"feature-shields\",\"message\":\"Match pull requests into main and test the pushed commit\",\"sha\":\"$FILE_SHA\",\"content\":\"$CONTENT\"}"
```

The new commit updates pull request #1, so Gitea sends a `pull_request` event, and Pipelines-as-Code reads the fixed template from the branch.

## Step 4: Check the run and the status

```sh
SHA="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/pulls/1 | jq -r .head.sha')"
kubectl get pipelineruns -n starfleet -l "pipelinesascode.tekton.dev/sha=$SHA"
kubectl get pipelineruns -n starfleet -l "pipelinesascode.tekton.dev/sha=$SHA" -o jsonpath='{.items[0].status.results[0].value}{"\n"}'
kubectl -n gitea exec deploy/tester -- sh -c "curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/commits/$SHA/statuses | jq -r '.[] | \"\(.context): \(.status)\"'"
```

The run ends with `SUCCEEDED` `True`, its result `commit` equals `$SHA`, and the newest status is `Pipelines as Code CI / pull-request: success`.

## Step 5: Submit

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Fix the template on `main` only | The pull request reads `.tekton` from `feature-shields`, which keeps the faults |
| Create a branch `master` and retarget the pull request | The grader requires a pull request into `main` |
| Keep `revision: main` | The run tests `main`; its result `commit` differs from the pull request head |
| Write the head SHA into the template | The commit that adds it has a new SHA, so it is always one commit behind |

## Common mistakes

- Fixing `on-event` and forgetting `on-target-branch`, or the other way round. Both must match.
- Writing `value: {{ revision }}` without quotes. It works after the replacement, but YAML tools reject the file before it.
- Looking at the first, older PipelineRun. The grader uses the newest head commit of the pull request.

## Practice on your own

- Open a second pull request from a new branch and see that it is tested at once.
- Change `on-target-branch` to `"[main, release-*]"` on a branch and test the pattern with `tkn pac info globbing -s "refs/heads/release-1.0" "refs/heads/release-*"`.
