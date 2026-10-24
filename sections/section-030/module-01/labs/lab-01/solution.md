# Solution: Queue Pull Request Runs With concurrency_limit

Work the task yourself first. Running `astrona submit -c sections/section-030/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: `concurrency_limit: 1` on the `Repository`; a successful `lint` and `unit-test` for the current head of pull request #1, where `unit-test` started at or after the time `lint` completed; and two `success` statuses on that commit.

## Step 1: Look at the first runs

```sh
kubectl get pipelineruns -n starfleet --sort-by=.metadata.creationTimestamp \
  -o custom-columns=NAME:.metadata.name,START:.status.startTime,DONE:.status.completionTime
```

The `lint` run and the `unit-test` run started within a second of each other, and each completed about twenty seconds later: they overlapped.

## Step 2: Set the limit

Save this as `repository-bridge-app.yaml`:

```yaml
apiVersion: pipelinesascode.tekton.dev/v1alpha1
kind: Repository
metadata:
  name: bridge-app
  namespace: starfleet
spec:
  url: "http://gitea-http.gitea.svc.cluster.local:3000/starfleet/bridge-app"
  concurrency_limit: 1
  git_provider:
    type: gitea
    url: "http://gitea-http.gitea.svc.cluster.local:3000"
    secret:
      name: gitea-webhook-config
      key: provider.token
    webhook_secret:
      name: gitea-webhook-config
      key: webhook.secret
```

Apply it:

```sh
kubectl apply -f repository-bridge-app.yaml
kubectl get repository bridge-app -n starfleet -o jsonpath='{.spec.concurrency_limit}{"\n"}'
```

The second command prints `1`.

## Step 3: Push a new commit to feature-sensors

The limit applies only to new events. Commit a new file to the pull request branch:

```sh
CONTENT="$(printf 'Calibration run after setting concurrency_limit.\n' | base64 | tr -d '\n')"
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X POST -H 'Content-Type: application/json' \
  http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/contents/docs/calibration.txt \
  --data "{\"branch\":\"feature-sensors\",\"message\":\"Record the sensor calibration\",\"content\":\"$CONTENT\"}"
```

The commit updates pull request #1. Watch the queue for about a minute:

```sh
kubectl get pipelineruns -n starfleet --sort-by=.metadata.creationTimestamp \
  -L pipelinesascode.tekton.dev/original-prname,pipelinesascode.tekton.dev/state
```

The two new runs appear together. `lint` is `started` while `unit-test` is `queued`; then `lint` is `completed` and `unit-test` starts.

## Step 4: Check the times and the statuses

```sh
kubectl get pipelineruns -n starfleet --sort-by=.metadata.creationTimestamp \
  -o custom-columns=NAME:.metadata.name,START:.status.startTime,DONE:.status.completionTime
SHA="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/pulls/1 | jq -r .head.sha')"
kubectl -n gitea exec deploy/tester -- sh -c "curl -sS -u starfleet:starfleet-password http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/commits/$SHA/statuses | jq -r '.[] | \"\(.context): \(.status)\"'"
```

The newest `unit-test` run starts at or after the time the newest `lint` run completed. The statuses include `Pipelines as Code CI / lint: success` and `Pipelines as Code CI / unit-test: success`.

## Step 5: Submit

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Set the limit and submit without a new commit | The head commit still has the overlapping runs from the start |
| Delete `unit-test` from `.tekton` | Only one run, but the team still needs both; the grader requires both |
| Add `runAfter` between the two templates | Templates are separate PipelineRuns; `runAfter` works only between Tasks of one Pipeline |
| `concurrency_limit: 0` | The admission webhook refuses it |

## Common mistakes

- Expecting the old runs to change. A limit affects only runs created after it.
- Reading `startTime` of a queued run. It has none until the watcher starts it.

## Practice on your own

- Set the limit to `2`, push a commit, and compare the times again.
- Open a second pull request while the first one runs, and see the runs of both wait in the same queue.
