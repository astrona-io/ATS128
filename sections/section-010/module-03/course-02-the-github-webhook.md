# The GitHub Webhook

Not every team can create a GitHub App: the account may not allow it, or the controller may have no public address that GitHub can reach for the App's webhook. The other way is a repository webhook with a token. The setup then looks like the Gitea setup in the labs. This part shows it for GitHub and compares it with the App.

## What the setup needs

For each repository you create two things. The first is a personal access token with rights on the repository, stored in a Secret. The second is a webhook on the repository that points at the controller and signs each request with a secret. The Secret holds both values:

| Key | Content |
| --- | --- |
| `provider.token` | The personal access token |
| `webhook.secret` | The webhook secret |

The token needs access to the repository contents, metadata, commit statuses, pull requests and issues. A fine-grained token limited to the repository is better than a classic token for all repositories. The webhook sends the events pull request, push, issue comment and commit comment, in the JSON content type.

<!-- astrona:playground:renew -->

## The Repository for a webhook

The object names the provider, the token and the webhook secret. Save this as `repository-github-webhook.yaml`:

```yaml
apiVersion: pipelinesascode.tekton.dev/v1alpha1
kind: Repository
metadata:
  name: bridge-app-github
  namespace: starfleet
spec:
  url: "https://github.com/starfleet/bridge-app"
  git_provider:
    secret:
      name: github-webhook-config
      key: provider.token
    webhook_secret:
      name: github-webhook-config
      key: webhook.secret
```

Ask the API server to validate it:

```sh
kubectl apply --dry-run=server -f repository-github-webhook.yaml
```

Then compare it with the object that connects Gitea:

```sh
kubectl -n starfleet get repository bridge-app -o jsonpath='{.spec.git_provider}{"\n"}'
```

The Gitea object has the same shape, with `type: gitea` and an extra `url` for the server. For github.com the provider is found from the URL, so `type` and `url` are not needed. For a GitHub Enterprise server, set `git_provider.url` to its API address.

## Add the webhook with the plugin

The plugin creates the webhook and the Secret for you:

```sh
tkn pac webhook add --help
```

It asks for the repository, the token and the controller URL, then creates the webhook on the Git server and writes the Secret. You can do the same by hand, as the labs do for Gitea.

## Which GitHub way to choose

| Question | GitHub App | Webhook with token |
| --- | --- | --- |
| Whose identity does the controller use? | The App | The person who owns the token |
| Does the token expire? | Installation tokens last about an hour | Until the token expires or is revoked |
| How does a run show? | Checks API | Commit status |
| How much setup per repository? | Install the App once for many repositories | A token, a Secret and a webhook for each |
| Does the `Repository` need `git_provider`? | No | Yes |
| Can the controller be private? | The App webhook must reach it | The repository webhook must reach it |

Large organizations choose the App for fewer secrets and richer checks. Small setups, GitHub Enterprise servers without apps, and tests choose the webhook.

## Common pitfalls

> [!WARNING]
> - **A classic token with every repository.** If it leaks, every repository is exposed.
> - **A webhook with the wrong content type.** The controller expects JSON.
> - **A missing `webhook_secret`.** The controller cannot check the signature and refuses requests.
> - **A token owned by a person who leaves.** Statuses and runs stop when the token is removed.
