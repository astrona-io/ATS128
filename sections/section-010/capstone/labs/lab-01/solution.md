# Solution: Repair A Broken Repository Connection

Work the task yourself first. Running `astrona submit -c sections/section-010/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: one `Repository` for the URL, in `starfleet`, with a working token and a webhook secret; the Gitea webhook on the controller Service port 8080; a successful PipelineRun in `starfleet` for the head of pull request #1; and the commit status `success` on that commit.

## Step 1: Find the Repository objects

Search the whole cluster, not only `starfleet`:

```sh
kubectl get repositories -A
```

There is one `Repository`, `bridge-app`, and it is in the namespace `default`. Events from the repository would start PipelineRuns there, not in `starfleet`. Because only one `Repository` may exist for a URL, you cannot simply add one in `starfleet` either: the admission webhook would answer `repository already exists with URL`. Delete the old one and its Secret:

```sh
kubectl -n default delete repository bridge-app
kubectl -n default delete secret gitea-webhook-config
```

## Step 2: Read the Secret in starfleet

List the keys of the Secret the team prepared:

```sh
kubectl -n starfleet get secret gitea-webhook-config -o jsonpath='{range $k, $v := .data}{$k}{"\n"}{end}'
```

The keys are `token` and `webhook.secret`. A `Repository` without `key` reads `provider.token`, which does not exist here. Set `key: token` in the `Repository`.

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
      key: token
    webhook_secret:
      name: gitea-webhook-config
      key: webhook.secret
```

Apply it:

```sh
kubectl apply -f repository-bridge-app.yaml
```

## Step 3: Check the Gitea webhook

List the webhooks of the repository:

```sh
kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/hooks | jq -r ".[] | \"\(.id) \(.type) \(.config.url)\""'
```

The webhook targets port **8082**, the container port of the controller. The Service `pipelines-as-code-controller` listens on 8080, so Gitea's delivery fails before any event reaches Pipelines-as-Code. Gitea cannot change the secret of an existing webhook, and you need the secret from the Secret anyway, so delete the webhook (use the `id` from the list) and create it again:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X DELETE \
  http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/hooks/<ID>
WEBHOOK_SECRET="$(kubectl -n starfleet get secret gitea-webhook-config -o jsonpath='{.data.webhook\.secret}' | base64 -d)"
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  -X POST -H 'Content-Type: application/json' \
  http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/hooks \
  --data "{\"type\":\"gitea\",\"active\":true,\"branch_filter\":\"*\",\"events\":[\"push\",\"pull_request\",\"pull_request_sync\",\"pull_request_comment\"],\"config\":{\"url\":\"http://pipelines-as-code-controller.pipelines-as-code.svc.cluster.local:8080\",\"content_type\":\"json\",\"secret\":\"$WEBHOOK_SECRET\"}}"
```

## Step 4: Send a new event and check the result

Gitea sent the pull request event long ago, to the wrong port. Close and reopen the pull request; Gitea sends a `reopened` event, and Pipelines-as-Code handles it like a new pull request:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X PATCH -H 'Content-Type: application/json' \
  http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/pulls/1 --data '{"state":"closed"}'
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X PATCH -H 'Content-Type: application/json' \
  http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/pulls/1 --data '{"state":"open"}'
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/event-type,pipelinesascode.tekton.dev/sha
```

A PipelineRun `pull-request-...` appears in `starfleet` and ends with `SUCCEEDED` `True`. If nothing appears, read `kubectl -n pipelines-as-code logs deploy/pipelines-as-code-controller --since=5m`. Then read the commit status:

```sh
SHA="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/pulls/1 | jq -r .head.sha')"
kubectl -n gitea exec deploy/tester -- sh -c "curl -sS -u starfleet:starfleet-password http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/commits/$SHA/statuses | jq -r '.[] | \"\(.context): \(.status)\"'"
```

## Step 5: Submit

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Leave the `Repository` in `default` | PipelineRuns run in `default`; the grader requires `starfleet` and only one `Repository` for the URL |
| Rename the Secret keys or create a new Secret | The task keeps the Secret as it is; set `key: token` in the `Repository` |
| Edit the webhook URL with PATCH and keep the secret | Works for the URL, but you cannot be sure the secret matches; recreate it with the secret from the Secret |
| Create a PipelineRun yourself | No Pipelines-as-Code labels and no commit status in Gitea |

## Common mistakes

- Looking only in `starfleet` with `kubectl get repositories`. Use `-A`.
- Fixing the `Repository` but not the webhook. Gitea's events still go to port 8082.
- Expecting the old pull request event to come back. Send a new one.

## Practice on your own

- Restore the webhook on port 8082 for a moment, reopen the pull request, and read Gitea's delivery list with `.../hooks/<ID>` in a browser through a port-forward.
- Set `key: provider.token` again and find the error message in `kubectl get events -n starfleet`.
