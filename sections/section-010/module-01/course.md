# Connect A Git Repository To Pipelines-as-Code

A team opens a pull request and wants to know, within minutes, whether the change builds and passes its tests. They also want the pipeline that does this to live in the same Git repository as the code, so that a change to the pipeline is reviewed like any other change. Pipelines-as-Code gives them both. It watches Git events, reads the PipelineRuns from the repository's `.tekton` folder, runs them with Tekton, and writes the result back to the pull request.

This module installs Pipelines-as-Code and connects one repository to it. Before anything can run, three things must line up: the cluster must know the repository (a `Repository` object), Pipelines-as-Code must be able to call the Git server (a token), and the Git server must tell Pipelines-as-Code about events (a webhook, signed with a shared secret). When all three are right, a new pull request starts a PipelineRun, and the pull request shows a green commit status.

Keep one sentence in mind: **the Git event starts the run, the `Repository` decides where it runs, and the `.tekton` folder decides what runs.**

The module has three parts. **What Pipelines-as-Code Is And How Events Become Runs** explains the model, the three components and the Git providers, including why GitHub Apps are the usual choice on GitHub and why your labs use Gitea instead. **Install Pipelines-as-Code And The tkn pac Plugin** installs the release and looks at what it created. **Connect A Repository With A Token And A Webhook** creates the Secret, the `Repository` and the webhook, then opens a pull request and follows it to a commit status. A graded lab follows the third part.

## Learning objectives

After this module you can:

- Explain the Pipelines-as-Code model: PipelineRuns in `.tekton`, started by Git events, results reported back to the Git provider.
- Name the controller, the watcher and the webhook of Pipelines-as-Code, and say what each one does.
- Explain what a `Repository` object is for and why only one may exist per repository URL.
- Compare a GitHub App, a GitHub webhook and the webhook-based providers (GitLab, Bitbucket, Forgejo and Gitea).
- Install Pipelines-as-Code v0.52.0 from its release manifest and check it with `kubectl` and `tkn pac`.
- Connect a repository with a token, a webhook secret, a `Repository` and a webhook, and prove it with a pull request.

## Before you start

You need Kubernetes basics (namespaces, pods, Secrets, Services, `kubectl apply`, `kubectl logs`), Git basics (branches, commits, pull requests) and a first look at Tekton: a `Pipeline` is an ordered list of Tasks, and a `PipelineRun` is one execution of it.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.17.1 |
| Namespace `gitea` | The Git server Gitea (Service `gitea-http`, port 3000), a `tester` pod with `curl` and `jq`, and the Secret `gitea-token` with an access token of the Gitea user `starfleet` |
| Gitea repository `starfleet/bridge-app` | A small application with `.tekton/pull-request.yaml` on `main`, and a branch `feature-hello` with one change |
| Namespace `starfleet` | Empty. The `Repository` and the PipelineRuns go here |
| `tkn` and `tkn pac` on your PATH | The Tekton command-line tool 0.46.2 and the Pipelines-as-Code plugin 0.52.0 |

Pipelines-as-Code itself is **not** installed yet: you install it in the second part. Every command runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
