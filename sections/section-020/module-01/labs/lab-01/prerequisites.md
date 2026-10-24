# Prerequisites

Before starting this lab you should be able to:

- Read the matching annotations `on-event` and `on-target-branch` of a PipelineRun template.
- Explain the difference between a dynamic variable such as `{{ revision }}` and a Tekton variable such as `$(params.revision)`.
- Say from which branch Pipelines-as-Code reads `.tekton` for a pull request.
- Commit a file to a branch through the Gitea API, or with `git` through a port-forward.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and **Pipelines-as-Code v0.52.0**, with `tkn` 0.46.2 and `tkn pac` 0.52.0 on your PATH.
- Gitea in the namespace `gitea` with the user `starfleet` (password `starfleet-password`, lab-only credentials) and a `tester` pod with `curl` and `jq` for the API.
- The repository `starfleet/bridge-app`, connected to Pipelines-as-Code through the `Repository` `bridge-app` in `starfleet`.
- Pull request #1 from `feature-shields` into `main`, open and never tested.

## Working rules

- Everything is graded on the **final state** of Gitea and the cluster. Leave pull request #1 open, into `main`.
- Do not change the `Repository`, the Secret or the webhook. They are correct.
