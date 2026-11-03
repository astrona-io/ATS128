# Connect Other Git Providers

Every lab in this course uses Gitea, because it runs inside the cluster. A real team usually uses GitHub, GitLab or Bitbucket. Pipelines-as-Code supports all of them, and the `Repository` object looks almost the same for each. What changes is how events arrive, which credential the controller uses and which events the Git server must send.

This module teaches those differences: the GitHub App, the GitHub webhook, GitLab, and Bitbucket Cloud and Data Center. The playground cannot reach these services, so you read the setup and check the `Repository` objects with a server dry run, which the admission webhook validates without creating anything.

Keep one sentence in mind: **the provider decides how the controller hears about an event and how it proves who it is when it answers.** The rest of Pipelines-as-Code does not change.

The module has four parts. **The GitHub App** covers the App identity, its keys and the Checks API. **The GitHub Webhook** covers a personal access token and a repository webhook, and compares both GitHub ways. **GitLab** covers the token, the webhook events and self-managed servers. **Bitbucket Cloud And Bitbucket Data Center** covers the user and app password, the token, and the source check for Cloud.

## Learning objectives

After this module you can:

- Describe what a GitHub App is, which Secret keys the controller reads and why the `Repository` needs no `git_provider` block.
- Set up a GitHub repository with a personal access token and a webhook.
- Choose between the GitHub App and the GitHub webhook.
- Write the `Repository` for GitLab, Bitbucket Cloud and Bitbucket Data Center.
- Name the events each provider must send for pull requests, pushes and comments.

## Before you start

You need to know what a `Repository` holds, how a token and a webhook secret connect a repository, and how the controller matches a URL.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `pipelines-as-code` | Pipelines-as-Code v0.52.0: controller, watcher and admission webhook |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.17.1 |
| Namespace `gitea` | Gitea (port 3000), the `tester` pod with `curl` and `jq`, and the token Secret `gitea-token` |
| Gitea repository `starfleet/bridge-app` | `.tekton/pull-request.yaml` and `.tekton/push.yaml` on `main` |
| Namespace `starfleet` | The `Repository` `bridge-app`, connected with the Secret `gitea-webhook-config` and a Gitea webhook |
| `tkn` and `tkn pac` on your PATH | The Tekton command-line tool 0.46.2 and the Pipelines-as-Code plugin 0.52.0 |

Every command runs against the playground cluster, and `kubectl` already points at it. The Gitea user `starfleet` and its password `starfleet-password` are lab-only credentials.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
