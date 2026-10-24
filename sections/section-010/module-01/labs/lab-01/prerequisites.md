# Prerequisites

Before starting this lab you should be able to:

- Explain what the controller, the watcher and the admission webhook of Pipelines-as-Code do.
- Write a `Repository` object with `spec.url` and `spec.git_provider`.
- Create a Kubernetes Secret with `kubectl create secret generic`.
- Call an HTTP API with `curl` and read JSON.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1**. Pipelines-as-Code is **not** installed.
- `tkn` 0.46.2 and `tkn pac` 0.52.0 on your PATH.
- Gitea in the namespace `gitea` (`http://gitea-http.gitea.svc.cluster.local:3000`, port 3000), with the user `starfleet` (password `starfleet-password`, lab-only credentials) and its access token in the Secret `gitea/gitea-token`, key `token`.
- The public repository `starfleet/bridge-app` with `.tekton/pull-request.yaml` on `main` and the branch `feature-hello`.
- A `tester` pod in the namespace `gitea` with `curl` and `jq`. Gitea is not reachable from your machine without a port-forward, so call its API from this pod with `kubectl -n gitea exec deploy/tester -- curl ...`.

## Working rules

- Everything is graded on the **final state** of the cluster and of Gitea. Leave the pull request open.
- Do not change the files in the repository. The `.tekton` folder is correct.
