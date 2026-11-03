# GitLab

GitLab calls a pull request a merge request, and it sends events through project webhooks. Pipelines-as-Code supports GitLab.com and self-managed GitLab servers with a token and a webhook, the same model as the Gitea setup. This part lists what to change and how the vocabulary maps.

## Token and events

The token is a project access token or a personal access token with the `api` scope, stored under `provider.token`. The project webhook sends these events to the controller: push events, tag push events, merge request events, comments (note events). The webhook has a secret token field, which is the `webhook.secret` value. GitLab sends it in the header `X-Gitlab-Token`, and the controller compares it with the Secret.

| GitLab word | Pipelines-as-Code event or variable |
| --- | --- |
| Merge request | The event `pull_request`, in `on-event` |
| Push event | The event `push` |
| Source and target branch | `{{ source_branch }}` and `{{ target_branch }}` |
| Note on a merge request | A comment, so `/retest` and `/ok-to-test` work |

GitLab accepts the same commands in a merge request comment. Templates use `pull_request` in `on-event` for merge requests, so a template written for another provider keeps working.

<!-- astrona:playground:renew -->

## The Repository for GitLab

For a self-managed server, `git_provider.url` is the base address of the server, and `type` is `gitlab`. Save this as `repository-gitlab.yaml`:

```yaml
apiVersion: pipelinesascode.tekton.dev/v1alpha1
kind: Repository
metadata:
  name: bridge-app-gitlab
  namespace: starfleet
spec:
  url: "https://gitlab.example.invalid/starfleet/bridge-app"
  git_provider:
    type: gitlab
    url: "https://gitlab.example.invalid"
    secret:
      name: gitlab-webhook-config
      key: provider.token
    webhook_secret:
      name: gitlab-webhook-config
      key: webhook.secret
```

The host name in the example is a placeholder. Replace it with your server. Validate the object without creating it:

```sh
kubectl apply --dry-run=server -f repository-gitlab.yaml
```

The server accepts it, because the URL is valid and unique. The admission webhook does not call GitLab, so a wrong token shows up only when an event arrives.

## Project paths with groups

A GitLab project path can have subgroups, such as `group/subgroup/project`. The `url` holds the whole path. The controller derives owner and name from it, and the variables `{{ repo_owner }}` and `{{ repo_name }}` follow that split. Check them in a resolved template before you depend on them.

## Statuses

The controller sets a commit status on the merge request pipeline of the commit, with the same name format: the application name, a slash and the PipelineRun name. The merge request shows these next to GitLab's own pipelines.

## Common pitfalls

> [!WARNING]
> - **A token without the `api` scope.** Reading works, but statuses and comments fail.
> - **A `git_provider.url` that includes the project path.** It is the base address of the server only.
> - **A self-signed certificate on the server.** The controller must trust it, or the API call fails. Fix the certificate chain on the controller side.
> - **Expecting GitLab CI to stop.** Pipelines-as-Code runs next to it. Disable the other pipeline if you do not want both.
