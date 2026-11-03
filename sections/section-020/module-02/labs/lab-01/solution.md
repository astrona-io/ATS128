# Solution: Define Custom Parameters On The Repository

Work the task yourself first. Running `astrona submit -c sections/section-020/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the params of the `Repository` and the untouched template; a successful PipelineRun for the current head of pull request #1 whose parameters hold the two values; and the commit status `success`.

## Step 1: Find the variables without a value

Read the log of the failed run with the `tkn pac` plugin:

```sh
tkn pac logs bridge-app -n starfleet -L
```

The `report` step prints `deploy_target={{ deploy_target }} log_level={{ log_level }}` and then `A custom parameter was not replaced.` Pipelines-as-Code replaces only the variables it knows: the standard ones such as `{{ revision }}` and the params of the `Repository`. It leaves any other `{{ name }}` as it is.

## Step 2: Define the params on the Repository

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
  params:
    - name: deploy_target
      value: shuttle-bay
    - name: log_level
      value: debug
```

Apply it:

```sh
kubectl apply -f repository-bridge-app.yaml
```

Then check the result:

```sh
kubectl -n starfleet get repository bridge-app -o jsonpath='{.spec.params}{"\n"}'
```

## Step 3: Run the pipeline again

The params apply to new events. Add the comment `/retest` to pull request #1:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  -X POST -H 'Content-Type: application/json' --data '{"body":"/retest"}' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/issues/1/comments
```

## Step 4: Check the run and the status

```sh
kubectl get pipelineruns -n starfleet --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{range .items[*]}{.metadata.name} {.spec.params[?(@.name=="deploy_target")].value} {.spec.params[?(@.name=="log_level")].value}{"\n"}{end}'
```

The newest run shows `shuttle-bay debug`. The older run shows the unreplaced `{{ deploy_target }}` text. Then read the commit status:

```sh
SHA="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/pulls/1 | jq -r .head.sha')"
kubectl -n gitea exec deploy/tester -- sh -c "curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/commits/$SHA/statuses | jq -r '.[] | \"\(.context): \(.status)\"'"
```

The newest line is `Pipelines as Code CI / pull-request: success`.

## Step 5: Submit

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Write the values into the template | The grader requires the template to keep the variables, so the values stay per repository |
| Skip `/retest` | The failed run stays the newest run of the head commit |
| Put `params` inside `spec.settings` | The field is `spec.params`; Pipelines-as-Code does not read params from anywhere else |

## Common mistakes

- Misspelling a param name. `deploy-target` does not replace `{{ deploy_target }}`.
- Looking at the old failed run. The grader uses the newest run of the head commit.

## Practice on your own

- Add a third param with a `filter` such as `pac.event_type == "pull_request"` and check that it is empty for a push.
- Change a value on the `Repository`, run `/retest`, and see that the new run holds the new value.
