# Prerequisites

Before starting this lab you should be able to:

- Explain how the pipelines-as-code-controller and the pipelines-as-code-watcher share the work of a queue.
- Edit and apply a `Repository` object.
- Read `status.startTime` and `status.completionTime` of a PipelineRun.
- Commit a file to a branch through the Gitea API, or with `git` through a port-forward.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and **Pipelines-as-Code v0.52.0**, with `tkn` 0.46.2 and `tkn pac` 0.52.0 on your PATH.
- Gitea in the namespace `gitea` with the user `starfleet` (password `starfleet-password`, lab-only credentials) and a `tester` pod with `curl` and `jq`.
- The repository `starfleet/bridge-app`, connected through the `Repository` `bridge-app` in `starfleet`, with the templates `lint` and `unit-test` (about 20 seconds each).
- Pull request #1 from `feature-sensors` into `main`. Its first `lint` and `unit-test` runs have finished; they ran at the same time.

## Working rules

- Everything is graded on the **final state** of Gitea and the cluster. Leave pull request #1 open.
- Keep both templates in `.tekton`.
