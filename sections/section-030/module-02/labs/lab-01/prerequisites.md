# Prerequisites

Before starting this lab you should be able to:

- Match a PipelineRun to an event type with `on-event` and `on-target-branch`.
- Create a Secret with `kubectl` and read a Secret value.
- Send an HTTP request with `curl` from a pod.
- Define a custom variable for a template.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and **Pipelines-as-Code v0.52.0**, with `tkn` 0.46.2 and `tkn pac` 0.52.0 on your PATH. The controller Service is `pipelines-as-code-controller` in the namespace `pipelines-as-code`, on port 8080.
- Gitea in the namespace `gitea` with the user `starfleet` (password `starfleet-password`, lab-only credentials) and a `tester` pod with `curl` and `jq`.
- The repository `starfleet/bridge-app`, connected through the `Repository` `bridge-app` in `starfleet`. Its `.tekton` folder holds `lint`, `unit-test` and `release`.

## Working rules

- Everything is graded on the **final state** of Gitea and the cluster.
- Do not change the Secret `gitea-webhook-config` or the Gitea webhook. They are correct.
