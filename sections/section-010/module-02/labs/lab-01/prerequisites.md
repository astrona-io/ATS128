# Prerequisites

Before starting this lab you should be able to:

- Say from which commit Pipelines-as-Code reads `.tekton` for a pull request by default.
- Read and change the `spec` of a `Repository` with `kubectl`.
- Start a pipeline again for a commit with a comment such as `/retest`, or by pushing a new commit.
- Read PipelineRun labels and a commit status through `kubectl` and the Gitea API.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and **Pipelines-as-Code v0.52.0**, with `tkn` 0.46.2 and `tkn pac` 0.52.0 on your PATH.
- Gitea in the namespace `gitea` with the user `starfleet` (password `starfleet-password`, lab-only credentials) and a `tester` pod with `curl` and `jq` for the API.
- The repository `starfleet/bridge-app`, connected through the `Repository` `bridge-app` in `starfleet`, with a correct `.tekton/pull-request.yaml` on `main`.
- Pull request #1 from `feature-tamper` into `main`. Its first run failed.

## Working rules

- Everything is graded on the **final state** of Gitea and the cluster.
- Do not change the Secret or the webhook. They are correct.
