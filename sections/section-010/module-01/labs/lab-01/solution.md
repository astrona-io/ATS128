# Solution: Connect A Gitea Repository To Pipelines-as-Code

Work the task yourself first. Running `astrona submit -c sections/section-010/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks five things: the installation (three Deployments on v0.52.0), the `Repository` (URL, provider, a working token, a webhook secret, no duplicate), the Gitea webhook (type `gitea`, pull request events, the controller Service on port 8080), a successful PipelineRun for the head of the pull request from `feature-hello`, and the commit status `Pipelines as Code CI / pull-request` = `success`.

## Step 1: Install Pipelines-as-Code

Apply the Kubernetes manifest of the release and wait for the three Deployments:

```sh
kubectl apply -f https://github.com/tektoncd/pipelines-as-code/releases/download/v0.52.0/release.k8s.yaml
kubectl -n pipelines-as-code rollout status deployment/pipelines-as-code-controller
kubectl -n pipelines-as-code rollout status deployment/pipelines-as-code-watcher
kubectl -n pipelines-as-code rollout status deployment/pipelines-as-code-webhook
kubectl -n pipelines-as-code get configmap pipelines-as-code-info -o jsonpath='{.data.version}{"\n"}'
```

The last command prints `v0.52.0`.

## Step 2: Create the Secret

Read the token and create the Secret with the two default keys:

```sh
TOKEN="$(kubectl -n gitea get secret gitea-token -o jsonpath='{.data.token}' | base64 -d)"
kubectl -n starfleet create secret generic gitea-webhook-config \
  --from-literal=provider.token="$TOKEN" \
  --from-literal=webhook.secret=bridge-webhook-secret
```

## Step 3: Create the Repository

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
```

Apply it:

```sh
kubectl apply -f repository-bridge-app.yaml
```

If the API server answers with an error that mentions the webhook `validation.pipelinesascode.tekton.dev`, the admission webhook is still starting: wait a few seconds and apply again.

## Step 4: Create the Gitea webhook

Create a webhook of type `gitea` that targets the Service port 8080:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  -X POST -H 'Content-Type: application/json' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/hooks \
  --data '{"type":"gitea","active":true,"branch_filter":"*","events":["push","pull_request","pull_request_sync","pull_request_comment"],"config":{"url":"http://pipelines-as-code-controller.pipelines-as-code.svc.cluster.local:8080","content_type":"json","secret":"bridge-webhook-secret"}}'
```

## Step 5: Open the pull request and check the result

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  -X POST -H 'Content-Type: application/json' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/pulls \
  --data '{"head":"feature-hello","base":"main","title":"Bump the version to 1.5.0"}'
```

Watch the PipelineRun that Pipelines-as-Code creates, until `SUCCEEDED` is `True`:

```sh
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/event-type,pipelinesascode.tekton.dev/sha
tkn pac describe bridge-app -n starfleet
```

Then read the commit status in Gitea:

```sh
SHA="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/pulls/1 | jq -r .head.sha')"
kubectl -n gitea exec deploy/tester -- sh -c "curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/commits/$SHA/statuses | jq -r '.[] | \"\(.context): \(.status)\"'"
```

The newest line is `Pipelines as Code CI / pull-request: success`. If no PipelineRun appears, read `kubectl -n pipelines-as-code logs deploy/pipelines-as-code-controller --since=5m`. If the pull request was opened before the webhook existed, close and reopen it to send a new event:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X PATCH -H 'Content-Type: application/json' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/pulls/1 --data '{"state":"closed"}'
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X PATCH -H 'Content-Type: application/json' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/pulls/1 --data '{"state":"open"}'
```

## Step 6: Submit

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Apply `release.yaml` | That manifest is for OpenShift; use `release.k8s.yaml` |
| Target the controller pod's IP or port 8082 | Pod IPs change and 8082 is the container port; the grader requires the Service on 8080 |
| `spec.url` with `localhost:3000` | Gitea sends its in-cluster URL in every event; the controller finds no matching `Repository` |
| Create the PipelineRun with `kubectl create` | It lacks the Pipelines-as-Code labels and no status reaches Gitea |
| Leave the webhook secret empty | Pipelines-as-Code refuses Gitea webhooks without a signature |

## Common mistakes

- Putting the Secret in the namespace `gitea` or `pipelines-as-code`. It must sit next to the `Repository`.
- Opening the pull request first and waiting. Gitea sent the event before the webhook existed.
- Using a webhook of type `gitea` with only the `push` event. Pull requests then never reach the controller.

## Practice on your own

- Push a commit to `feature-hello` and watch a second PipelineRun appear for the new head commit.
- Read the comment Pipelines-as-Code posted on the pull request with `kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/issues/1/comments`.
- Compare `tkn pac list -n starfleet` with `kubectl get repositories -n starfleet`.
