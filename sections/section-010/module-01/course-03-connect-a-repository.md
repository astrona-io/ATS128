# Connect A Repository With A Token And A Webhook

An installed Pipelines-as-Code does nothing until a repository is connected to it. A connection has two directions. Pipelines-as-Code must be able to call the Git provider, to read `.tekton` and to write statuses, so it needs a token. The Git provider must be able to tell Pipelines-as-Code about events, so it needs a webhook, and both sides need the same webhook secret to trust each other. This part builds both directions for `starfleet/bridge-app` and then follows a pull request to its commit status.

## The token and the webhook secret

A personal access token is a token of a Gitea user account; Pipelines-as-Code sends it with every API call. Your playground created one for the user `starfleet`, with the rights to read and write repositories and issues, and stored it in the Secret `gitea-token` in the namespace `gitea`. A webhook secret is a shared string: Gitea signs each webhook body with it (HMAC-SHA256, in the header `X-Gitea-Signature`), and Pipelines-as-Code refuses any webhook whose signature does not match. Gitea webhooks without a secret are refused too.

<!-- astrona:playground:renew -->

Read the token into a shell variable, then store it together with a webhook secret in a Secret next to the future `Repository`. The keys `provider.token` and `webhook.secret` are the names Pipelines-as-Code reads by default:

```sh
TOKEN="$(kubectl -n gitea get secret gitea-token -o jsonpath='{.data.token}' | base64 -d)"
kubectl -n starfleet create secret generic gitea-webhook-config \
  --from-literal=provider.token="$TOKEN" \
  --from-literal=webhook.secret=bridge-webhook-secret
```

The command prints `secret/gitea-webhook-config created`. On a real system, generate the webhook secret with a random generator, for example `head -c 30 /dev/random | base64`.

## The Repository

The `Repository` names the repository URL, the provider type, the provider's API address and the two Secret keys. The URL must be exactly the address Gitea puts in its webhooks. Gitea in your playground uses its in-cluster address, `http://gitea-http.gitea.svc.cluster.local:3000`.

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

Then check the result:

```sh
kubectl get repositories -n starfleet
tkn pac list -n starfleet
```

`kubectl` shows `bridge-app` with its URL. `tkn pac list` shows the same `Repository`, with no run yet. The Secret must sit in the same namespace as the `Repository`: Pipelines-as-Code never reads a Secret from another namespace for it.

## The webhook

The last piece is on the Gitea side: a webhook of the type `gitea` that sends push and pull request events to the controller Service. Gitea normally refuses to send webhooks to private addresses; your playground's Gitea allows them with its setting `ALLOWED_HOST_LIST=private`, because the controller is a Service inside the cluster.

Create the webhook with the Gitea API from the `tester` pod. The events `pull_request` and `pull_request_sync` cover opened and updated pull requests, and `pull_request_comment` carries comments such as `/retest`:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  -X POST -H 'Content-Type: application/json' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/hooks \
  --data '{"type":"gitea","active":true,"branch_filter":"*","events":["push","pull_request","pull_request_sync","pull_request_comment"],"config":{"url":"http://pipelines-as-code-controller.pipelines-as-code.svc.cluster.local:8080","content_type":"json","secret":"bridge-webhook-secret"}}'
```

Gitea answers with the JSON of the new webhook, including its `id` and `"active": true`. Gitea never shows the secret again, and it cannot change the secret of an existing webhook: to use a new secret, delete the webhook and create it again.

## A pull request starts a run

Everything is connected, so open a pull request from `feature-hello` into `main`. The branch changes `app/VERSION`:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  -X POST -H 'Content-Type: application/json' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/pulls \
  --data '{"head":"feature-hello","base":"main","title":"Bump the version to 1.5.0"}'
```

Gitea answers with the pull request, number `1`. Gitea sends a `pull_request` webhook to the controller at the same time. Watch the PipelineRun appear in `starfleet`:

```sh
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/event-type,pipelinesascode.tekton.dev/sha
```

After a few seconds, a PipelineRun named `pull-request-` plus five random characters appears, with the event type `pull_request` and the commit SHA of the pull request's head. Run the command again until its `SUCCEEDED` column shows `True`; the first run pulls the `alpine/git` and `busybox` images from the node, which is quick because they are preloaded. The labels come from Pipelines-as-Code; `tkn pac describe bridge-app -n starfleet` shows the same run from the point of view of the `Repository`.

Now look at the result from the Git side. The commit statuses of the head commit belong to Gitea:

```sh
SHA="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/pulls/1 | jq -r .head.sha')"
kubectl -n gitea exec deploy/tester -- sh -c "curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/commits/$SHA/statuses | jq -r '.[] | \"\(.context): \(.status) (\(.description))\"'"
```

The newest line reads `Pipelines as Code CI / pull-request: success`, and an older line shows the `pending` status that the controller wrote when the run started. The watcher wrote the final status when the run finished. Pipelines-as-Code also posted a comment on the pull request with the result of each task.

> [!TIP]
> **Follow the event when nothing happens.** Read the controller log with `kubectl -n pipelines-as-code logs deploy/pipelines-as-code-controller --since=5m` and the events of the namespace with `kubectl get events -n starfleet`. Gitea's delivery list does not help much: the controller answers every webhook with HTTP 202 before it checks the signature or looks for a `Repository`.

If a pull request was opened before the webhook existed, Gitea sent nothing. Push a new commit to the branch, or close and reopen the pull request, to make Gitea send a new event.

You can now connect a repository: a Secret with the token and the webhook secret, a `Repository` in the namespace where the runs belong, and a webhook to the controller Service on port 8080. A pull request then becomes a PipelineRun and a commit status. The open question is how to write the PipelineRuns in `.tekton` so that each event starts exactly the right ones.

## Common pitfalls

> [!WARNING]
> - **A `Repository` URL that differs from the one Gitea sends.** The controller compares the repository URL of the event with `spec.url`. A different host name (`localhost` instead of the in-cluster name) means no match and no run.
> - **The wrong Secret key.** Without `key`, Pipelines-as-Code reads `provider.token` and `webhook.secret`. A Secret with the key `token` needs `key: token` in the `Repository`.
> - **Different webhook secrets on the two sides.** The controller refuses the event. Only its log shows why.
> - **A webhook of type `gitea` that does not send pull request events.** Choose `pull_request` (and `pull_request_sync`, `pull_request_comment`), not only `push`.
> - **Waiting for a run on a pull request opened before the webhook.** Send a new event: push a commit, or close and reopen the pull request.

## Your mission: Connect A Gitea Repository To Pipelines-as-Code

You can now install Pipelines-as-Code and connect a repository so that a pull request runs a pipeline. The graded lab starts from a cluster without Pipelines-as-Code and asks you to install it, connect `starfleet/bridge-app`, open a pull request and get a green status on it.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-128-playground-010-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS128.git -c sections/section-010/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-128-lab-010-01
astrona start ats-128-playground-010-01
```
