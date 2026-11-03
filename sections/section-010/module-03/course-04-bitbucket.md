# Bitbucket Cloud And Bitbucket Data Center

Bitbucket comes in two products with different APIs. Bitbucket Cloud is Atlassian's hosted service. Bitbucket Data Center is the self-managed server. Pipelines-as-Code has a separate provider type for each: `bitbucket-cloud` and `bitbucket-datacenter`. This part shows what each needs and how they differ from the token and webhook model used so far.

## Bitbucket Cloud

Cloud authenticates with a user name and an app password. The user goes in `git_provider.user`, and the app password goes in the Secret under `provider.token`. The app password needs rights to read repositories, to write pull requests and to read and write webhooks. The webhook sends repository push events and pull request events: created, updated and comment created.

Bitbucket Cloud does not sign its webhook requests with a shared secret. The controller instead checks that the source address of each request is one of the addresses Atlassian publishes. Two keys of the ConfigMap `pipelines-as-code` control this: one turns the check on or off, and one adds your own addresses. Read the ConfigMap in your release for the exact key names:

<!-- astrona:playground:renew -->

```sh
kubectl -n pipelines-as-code get configmap pipelines-as-code -o yaml | grep -i bitbucket
```

Save this as `repository-bitbucket-cloud.yaml`:

```yaml
apiVersion: pipelinesascode.tekton.dev/v1alpha1
kind: Repository
metadata:
  name: bridge-app-bitbucket
  namespace: starfleet
spec:
  url: "https://bitbucket.org/starfleet/bridge-app"
  git_provider:
    type: bitbucket-cloud
    user: starfleet
    secret:
      name: bitbucket-config
      key: provider.token
```

Validate it without creating it:

```sh
kubectl apply --dry-run=server -f repository-bitbucket-cloud.yaml
```

## Bitbucket Data Center

Data Center uses a personal access token (HTTP access token) and needs the server address, because every installation has its own. The `url` of the provider is the base address of the server. The webhook supports a secret, so `webhook_secret` works as for Gitea. Save this as `repository-bitbucket-datacenter.yaml`:

```yaml
apiVersion: pipelinesascode.tekton.dev/v1alpha1
kind: Repository
metadata:
  name: bridge-app-datacenter
  namespace: starfleet
spec:
  url: "https://bitbucket.example.invalid/projects/STAR/repos/bridge-app"
  git_provider:
    type: bitbucket-datacenter
    url: "https://bitbucket.example.invalid"
    secret:
      name: bitbucket-dc-config
      key: provider.token
    webhook_secret:
      name: bitbucket-dc-config
      key: webhook.secret
```

The host name is a placeholder. Validate it:

```sh
kubectl apply --dry-run=server -f repository-bitbucket-datacenter.yaml
```

## Compare the providers

| Provider | `git_provider.type` | Needs `url` | Needs `user` | Webhook secret |
| --- | --- | --- | --- | --- |
| GitHub App | not set | no | no | in the installation Secret |
| GitHub webhook | not set or `github` | Enterprise only | no | yes |
| GitLab | `gitlab` | self-managed | no | yes |
| Gitea and Forgejo | `gitea` or `forgejo` | yes | no | yes |
| Bitbucket Cloud | `bitbucket-cloud` | no | yes | no, source address check |
| Bitbucket Data Center | `bitbucket-datacenter` | yes | no | yes |

Features also differ. Not every provider supports every comment command or every status detail, so read the provider page of your release before you promise a feature to a team.

## Common pitfalls

> [!WARNING]
> - **A missing `user` for Bitbucket Cloud.** The app password cannot be used without it.
> - **Expecting a webhook secret on Bitbucket Cloud.** Use the source address check and keep the controller reachable only as needed.
> - **The server address with a path for Data Center.** `git_provider.url` is the base address only.
> - **An account password instead of an app password.** Use a token with limited rights.
