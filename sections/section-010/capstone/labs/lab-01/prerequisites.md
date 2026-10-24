# Prerequisites

Before starting this capstone you should be able to:

- Explain how a Gitea webhook becomes a PipelineRun, and which component does each step.
- Read the controller log of Pipelines-as-Code and the events of a namespace.
- Write a `Repository` with `git_provider.secret` and `git_provider.webhook_secret`, including `key`.
- Create, list and delete Gitea webhooks with the Gitea API.

## What the environment gives you

The capstone environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and **Pipelines-as-Code v0.52.0**, with `tkn` 0.46.2 and `tkn pac` 0.52.0 on your PATH.
- Gitea in the namespace `gitea` with the user `starfleet` (password `starfleet-password`, lab-only credentials), its token in `gitea/gitea-token`, and the repository `starfleet/bridge-app`.
- Pull request #1 from `feature-hello` into `main`, open and never tested.
- A `tester` pod in the namespace `gitea` with `curl` and `jq` for the Gitea API.

## Working rules

- Everything is graded on the **final state** of the cluster and of Gitea. Leave pull request #1 open.
- Do not change the files in the repository.
