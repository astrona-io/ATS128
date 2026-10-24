# Prerequisites

Before starting this capstone you should be able to:

- Explain how Pipelines-as-Code checks the signature of a Gitea webhook, and where a failed check shows up.
- Name who may run pipelines on a repository, and what Pipelines-as-Code does for anyone else.
- Use the GitOps command `/ok-to-test`, and write an `OWNERS` file.
- Recreate a Gitea webhook and edit a Kubernetes Secret.

## What the environment gives you

The capstone environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and **Pipelines-as-Code v0.52.0**, with `tkn` 0.46.2 and `tkn pac` 0.52.0 on your PATH.
- Gitea in the namespace `gitea` with the users `starfleet` (owner, password `starfleet-password`) and `cadet` (no rights on the repository, password `cadet-password`); both are lab-only credentials. A `tester` pod with `curl` and `jq`.
- The repository `starfleet/bridge-app` with `.tekton/pull-request.yaml`, the `Repository` `bridge-app` and the Secret `gitea-webhook-config` in `starfleet`, and a Gitea webhook.
- The fork `cadet/bridge-app` and pull request #1 from `cadet:docs-typo` into `starfleet/bridge-app` `main`.

## Working rules

- Everything is graded on the **final state** of Gitea and the cluster. Leave pull request #1 open.
- Do not make `cadet` a collaborator of `starfleet/bridge-app`.
