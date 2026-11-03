# Solution: Run Pull Requests With The Pipeline From The Default Branch

Work the task yourself first. Running `astrona submit -c sections/section-010/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the `Repository` setting and the untouched branch; a successful PipelineRun for the current head of pull request #1 that does not contain the changed test step; and the commit status `success`.

## Step 1: Compare the two definitions

By default, Pipelines-as-Code reads `.tekton` from the branch of the pull request. Read the test step on both branches:

```sh
for ref in main feature-tamper; do
  echo "--- $ref"
  kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
    "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/raw/.tekton/pull-request.yaml?ref=$ref" | tail -6
done
```

On `main` the test step runs `sh app/status.sh`. On `feature-tamper` it prints `tampered pipeline: skipping the status check` and runs `exit 1`. The first run of pull request #1 used the branch's definition, so it failed.

## Step 2: Set the provenance on the Repository

Save this as `repository-bridge-app.yaml`:

```yaml
apiVersion: pipelinesascode.tekton.dev/v1alpha1
kind: Repository
metadata:
  name: bridge-app
  namespace: starfleet
spec:
  url: "http://gitea-http.gitea.svc.cluster.local:3000/starfleet/bridge-app"
  git_provider:
    type: gitea
    url: "http://gitea-http.gitea.svc.cluster.local:3000"
    secret:
      name: gitea-webhook-config
      key: provider.token
    webhook_secret:
      name: gitea-webhook-config
      key: webhook.secret
  settings:
    pipelinerun_provenance: default_branch
```

Apply it:

```sh
kubectl apply -f repository-bridge-app.yaml
```

Then check the result:

```sh
kubectl -n starfleet get repository bridge-app -o jsonpath='{.spec.settings}{"\n"}'
```

## Step 3: Run the pipeline again

The setting applies to new events. Add the comment `/retest` to pull request #1 as the user `starfleet`. The controller then starts the pipelines again for the head commit:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  -X POST -H 'Content-Type: application/json' --data '{"body":"/retest"}' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/issues/1/comments
```

## Step 4: Check the run and the status

```sh
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/original-prname,pipelinesascode.tekton.dev/sha
```

The newest `pull-request` run for the head commit shows `SUCCEEDED` `True`. The older run for the same commit shows `False`. Then read the commit status:

```sh
SHA="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/pulls/1 | jq -r .head.sha')"
kubectl -n gitea exec deploy/tester -- sh -c "curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/commits/$SHA/statuses | jq -r '.[] | \"\(.context): \(.status)\"'"
```

The newest line is `Pipelines as Code CI / pull-request: success`.

## Step 5: Submit

```sh
astrona submit -c sections/section-010/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Revert the change on `feature-tamper` | The grader requires the branch to stay as it is; the fix is a setting that protects every pull request |
| Create a second `Repository` for the same URL | Pipelines-as-Code refuses to match a repository that has two `Repository` objects |
| Set the setting and wait | The setting applies to new events; the failed run for the same commit stays the newest until another event arrives |

## Common mistakes

- Writing `pipelinerun_provenance` at the top of `spec` instead of under `spec.settings`.
- Using the value `main` or `default`. The accepted values are `source` and `default_branch`.
- Looking at the old failed run. The grader uses the newest run of the head commit.

## Practice on your own

- Change the setting back to `source`, push a new commit to the branch, and watch the failing definition run again.
- Open a pull request that changes only `docs/guide.md` and compare its run with the run of pull request #1.
