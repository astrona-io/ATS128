# Prerequisites

Before starting this lab you should be able to:

- Explain the difference between a dynamic variable such as `{{ revision }}` and a Tekton variable such as `$(params.revision)`.
- Say what Pipelines-as-Code does with a `{{ name }}` that it does not know.
- Read and change the `spec` of a `Repository` with `kubectl`.
- Start a pipeline again for a commit with a comment such as `/retest`.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and **Pipelines-as-Code v0.52.0**, with `tkn` 0.46.2 and `tkn pac` 0.52.0 on your PATH.
- Gitea in the namespace `gitea` with the user `starfleet` (password `starfleet-password`, lab-only credentials) and a `tester` pod with `curl` and `jq` for the API.
- The repository `starfleet/bridge-app`, connected through the `Repository` `bridge-app` in `starfleet`.
- Pull request #1 from `feature-params` into `main`. Its first run failed.

## Working rules

- Everything is graded on the **final state** of Gitea and the cluster.
- Do not change the Secret or the webhook. They are correct.
