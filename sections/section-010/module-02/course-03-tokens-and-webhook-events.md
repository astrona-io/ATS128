# Tokens, Webhook Events And The tkn pac Commands

Pipelines-as-Code needs two things from a Git server: a way to hear about events and a credential to call the server API. Events arrive as webhook requests. The credential is a token that lets the controller read files, post comments and set commit statuses. This part lists what each provider needs, shows how to rotate a token and explains what a wrong token or a missing webhook event looks like.

## Providers and what they need

| Provider | How events arrive | Credential in the Secret | Events or rights |
| --- | --- | --- | --- |
| GitHub App | The App sends events to the controller | None in the `Repository`. The App has its own key | Set when the App is installed |
| GitHub webhook | A repository webhook | A personal access token in `provider.token` | Repository contents, pull requests, issues and commit statuses |
| GitLab | A project webhook | A project or personal access token with the `api` scope | Push, merge request, comment and tag events |
| Bitbucket Cloud | A repository webhook | An app password, with the user name in `git_provider.user` | Push, pull request and comment events |
| Bitbucket Data Center | A repository webhook | A personal access token | Push, pull request and comment events |
| Gitea | A repository webhook | An access token | Push, pull request and comment events |

A Gitea or GitLab webhook has a secret too. The controller checks the signature of every request against `webhook_secret`, and drops requests that do not match. The Secret holds both values, under the keys you name in the `Repository`.

<!-- astrona:playground:renew -->

Read the Secret of the playground without printing the values:

```sh
kubectl -n starfleet get secret gitea-webhook-config -o jsonpath='{.data}' | jq 'keys'
```

The keys are `provider.token` and `webhook.secret`. These key names are your choice, because the `Repository` names them.

## Read the webhook of the Git server

The webhook is created on the Git server and not in the cluster. List it from Gitea:

```sh
kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/hooks | jq ".[] | {id, active, events, url: .config.url}"'
```

The `url` points to the controller service of Pipelines-as-Code, `active` is `true`, and `events` lists the event names that Gitea sends. If a provider is not allowed to send an event, no run starts for it, even when everything in the cluster is right. A run on a pull request comment needs the comment event, and a run on a tag needs the push event.

## Rotate a token

Tokens expire or leak, so they get replaced. The cluster side of the change is one Secret. Create a new token in Gitea, then replace the value. The command below reads the new token from a shell variable named `NEWTOKEN` so that it does not appear in the file:

```sh
kubectl -n starfleet create secret generic gitea-webhook-config \
  --from-literal=provider.token="$NEWTOKEN" \
  --from-literal=webhook.secret="$(kubectl -n starfleet get secret gitea-webhook-config -o jsonpath='{.data.webhook\.secret}' | base64 -d)" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Both keys are written again, because `apply` of a Secret with one key removes the other. The `Repository` needs no change, as it points at the Secret by name. The next event uses the new token.

## Symptoms of a wrong credential

The controller log tells which side is wrong. Read it after you push a commit:

```sh
kubectl -n pipelines-as-code logs deploy/pipelines-as-code-controller --tail=40
```

Use these signs to decide where to look:

- **No log line for your push.** The request never reached the controller. Check the webhook url, its events and its delivery list in the Git server.
- **A line about an invalid signature or a webhook secret.** The `webhook_secret` in the Secret differs from the secret in the webhook.
- **A line about a failed API call, such as 401 or 403.** The token is wrong, expired or has too few rights.
- **A line that no `Repository` matches the URL.** The `url` differs from the one in the payload, or the namespace has no `Repository`.

The exact wording depends on the release, so read your log instead of searching for a fixed text.

## The tkn pac commands

The plugin works from the cluster and does not need the Git server:

```sh
tkn pac list -n starfleet
tkn pac describe bridge-app -n starfleet
tkn pac logs bridge-app -n starfleet --last
```

`tkn pac list` shows each `Repository` with its last run. `tkn pac describe` lists the recent runs from the history in the object with their results. `tkn pac logs` prints the logs of a run, the last one with `--last`. The plugin reads the same data you read with `kubectl` and puts it in one view.

## Common pitfalls

> [!WARNING]
> - **A token with too few rights.** Reading works, but setting the commit status or posting a comment fails with 403.
> - **Rotating the token with a one-key Secret.** The webhook secret is dropped, and every webhook request is then refused.
> - **Changing the webhook secret on one side only.** Change the Git server and the Secret together.
> - **Printing a Secret into a shared terminal or a ticket.** Show the key names only.
