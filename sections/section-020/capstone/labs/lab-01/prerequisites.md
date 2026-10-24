# Prerequisites

Before starting this capstone you should be able to:

- Write `on-event` and `on-target-branch` with branch globs.
- Explain what happens when a PipelineRun has `on-cel-expression` next to other matching annotations.
- Explain what two PipelineRuns with the same name in `.tekton` do to an event.
- Use `max-keep-runs`, and commit or delete files on a branch through the Gitea API.

## What the environment gives you

The capstone environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and **Pipelines-as-Code v0.52.0**, with `tkn` 0.46.2 and `tkn pac` 0.52.0 on your PATH.
- Gitea in the namespace `gitea` with the user `starfleet` (password `starfleet-password`, lab-only credentials) and a `tester` pod with `curl` and `jq`.
- The repository `starfleet/bridge-app`, connected to Pipelines-as-Code, with the branches `main`, `release-1.0` and `feature-engines`.

## Working rules

- Everything is graded on the **final state** of Gitea and the cluster. Keep the branches `release-1.0` and `feature-engines`.
- The grader commits files under `grader/` to three branches and waits for the runs. That takes a few minutes.
