# Control How Pipeline Runs Report, Queue And Start

A pipeline that runs is only half of continuous integration. The other half happens around the run. The author of a pull request must see the result without opening the cluster. The cluster must not run twenty pipelines at once because twenty commits arrived in a minute. And a stranger's pull request must not run code with the team's secrets before someone has read it. Pipelines-as-Code handles all three, and this module shows how.

You first follow a run's result back to the Git provider: the commit status, the pull request comment, the GitHub checks, and the `tkn pac` commands that show the same from the cluster. Then you limit how many runs of a repository may run at the same time, and see how Pipelines-as-Code queues the rest. Last, you learn who may start a run, and how an allowed user lets an outside contributor's pull request run with a comment.

Keep one sentence in mind: **the watcher reports and queues, the controller decides who may run.**

The module has three parts. **How Pipelines-as-Code Reports Status** explains what each provider shows, including a failed run's log snippet. **Queue Runs With concurrency_limit** sets a limit on the `Repository` and watches the queue; a graded lab follows it. **Control Who Can Run Pipelines** covers the access rules, the `OWNERS` file and the GitOps commands `/ok-to-test`, `/retest`, `/test` and `/cancel`.

## Learning objectives

After this module you can:

- Explain how Pipelines-as-Code reports a run on a GitHub App, a GitHub webhook and Gitea, and read the commit statuses and comments.
- Read the runs of a repository with `tkn pac list`, `tkn pac describe` and `tkn pac logs`.
- Limit parallel runs with `concurrency_limit`, and explain the queue and the `state` label.
- Explain `cancel-in-progress` and why it cannot be combined with a concurrency limit.
- Name who may run pipelines, and trust a contributor with the `OWNERS` file.
- Use `/ok-to-test`, `/retest`, `/test <name>` and `/cancel` on a pull request.

## Before you start

You need a connected repository in mind: a `Repository` object, a token and a webhook, and PipelineRun templates in `.tekton` with `on-event` and `on-target-branch`. You should know that the pipelines-as-code-controller creates the PipelineRuns and the pipelines-as-code-watcher follows them.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `pipelines-as-code` | Pipelines-as-Code v0.52.0: controller, watcher and admission webhook |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.17.1 |
| Namespace `gitea` | Gitea (port 3000) with the users `starfleet` (owner) and `cadet` (no rights on the repository), and the `tester` pod with `curl` and `jq` |
| Gitea repository `starfleet/bridge-app` | `.tekton/lint.yaml` and `.tekton/unit-test.yaml`: two pull request pipelines of about 20 seconds each |
| Namespace `starfleet` | The `Repository` `bridge-app`, connected with the Secret `gitea-webhook-config` and a Gitea webhook |
| `tkn` and `tkn pac` on your PATH | The Tekton command-line tool 0.46.2 and the Pipelines-as-Code plugin 0.52.0 |

Every command runs against the playground cluster, and `kubectl` already points at it. The Gitea passwords `starfleet-password` and `cadet-password` are lab-only credentials.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
