# Comments, Incoming Webhooks And Troubleshooting

Not every run starts with a push or a new pull request. A reviewer wants to run a failed check again, a maintainer wants to start one named pipeline, a scheduler outside Git wants to start a release, and a stranger's pull request needs a decision before anything runs. Pipelines-as-Code handles these with comments and incoming webhooks. When something does not start, you also need a way to find out why.

This module teaches the comment commands, how a template can react to its own comment, how to start a pipeline from outside Git with an incoming webhook, and how to find out why a run did not start.

Keep one sentence in mind: **a run starts because an event matched a template, and a comment or an incoming webhook is also an event.** Troubleshooting is finding the first step in that chain that did not happen.

The module has five parts. **Comment Commands On A Pull Request** covers `/retest`, `/test`, `/cancel` and `/ok-to-test`, and who may use them. **Run A Template From A Comment** covers `on-comment` and `{{ trigger_comment }}`. **Incoming Webhooks** covers the `incoming` field of the `Repository`, the endpoint and the request, and a graded lab follows it. **Find Out Why A Run Did Not Start** covers the order of checks and where each one is read. **Act On Runs From The Command Line** covers `tkn` and `tkn pac` for listing, reading, cancelling and cleaning up runs.

## Learning objectives

After this module you can:

- Restart, select and cancel runs with comments, and say who is allowed to.
- Approve a run for a pull request from a user without rights with `/ok-to-test`.
- Write a template that starts from a comment and reads the comment text.
- Configure an incoming webhook, call it, and explain what each query parameter does.
- Find why a run did not start by checking the webhook delivery, the controller log, the matching and the PipelineRuns in order.

## Before you start

You need to know how `on-event` and `on-target-branch` select a template, what a `Repository` holds, and how concurrency limits queue runs. You also need to read a Tekton `PipelineRun`.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `pipelines-as-code` | Pipelines-as-Code v0.52.0: controller, watcher and admission webhook |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.17.1 |
| Namespace `gitea` | Gitea (port 3000) with the users `starfleet` (owner) and `cadet` (no rights on the repository), and the `tester` pod with `curl` and `jq` |
| Gitea repository `starfleet/bridge-app` | `.tekton/lint.yaml` and `.tekton/unit-test.yaml` for pull requests, `.tekton/release.yaml` for incoming webhooks and `.tekton/status-report.yaml` for the comment `/status-report` |
| Namespace `starfleet` | The `Repository` `bridge-app`, connected with the Secret `gitea-webhook-config` and a Gitea webhook |
| `tkn` and `tkn pac` on your PATH | The Tekton command-line tool 0.46.2 and the Pipelines-as-Code plugin 0.52.0 |

Every command runs against the playground cluster, and `kubectl` already points at it. The Gitea passwords `starfleet-password` and `cadet-password` are lab-only credentials.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
