# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Repository connection

## Scenario

The `starfleet` team keeps its bridge application in the Gitea repository `starfleet/bridge-app`. The repository already holds a pipeline in `.tekton/pull-request.yaml`, but nothing runs it: Pipelines-as-Code is not even installed. The team wants every pull request into `main` to be tested in the namespace `starfleet`, with the result shown on the pull request.

## Your task

1. Install **Pipelines-as-Code v0.52.0** on the cluster from its Kubernetes release manifest.
2. In the namespace `starfleet`, create the Secret `gitea-webhook-config` with the Gitea token of the user `starfleet` (the Secret `gitea/gitea-token` holds it) and a webhook secret of your choice.
3. In the namespace `starfleet`, create the `Repository` `bridge-app` for `http://gitea-http.gitea.svc.cluster.local:3000/starfleet/bridge-app`, with the Gitea provider at `http://gitea-http.gitea.svc.cluster.local:3000` and your Secret.
4. Add a Gitea webhook to `starfleet/bridge-app` that sends push and pull request events to the Pipelines-as-Code controller, signed with your webhook secret.
5. Open a pull request from `feature-hello` into `main`.

## Constraints

- Install from the release manifest of v0.52.0; do not change its objects.
- The webhook must target the controller **Service**, not a pod, from inside the cluster.
- Do not create a second `Repository` for the same URL, and do not create PipelineRuns yourself: Pipelines-as-Code must create them.

## Done when

- The Deployments `pipelines-as-code-controller`, `pipelines-as-code-watcher` and `pipelines-as-code-webhook` run v0.52.0, and the ConfigMap `pipelines-as-code-info` reports `v0.52.0`.
- The `Repository` `bridge-app` in `starfleet` has the URL above, the provider type `gitea` (or `forgejo`) with the Gitea URL, a Secret whose token Gitea accepts for `starfleet`, and a non-empty webhook secret. No other `Repository` uses that URL.
- `starfleet/bridge-app` has an active webhook of type `gitea` that sends pull request events to `http://pipelines-as-code-controller.pipelines-as-code.svc.cluster.local:8080`.
- An open pull request from `feature-hello` into `main` has a PipelineRun created by Pipelines-as-Code in `starfleet` for its head commit. The run succeeded, carries the labels `pipelinesascode.tekton.dev/event-type=pull_request` and `pipelinesascode.tekton.dev/repository=bridge-app`, and its result `commit` is that head commit.
- Gitea shows the commit status `Pipelines as Code CI / pull-request` with the state `success` on that commit.
