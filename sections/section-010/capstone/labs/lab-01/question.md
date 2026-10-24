# Question

Solve this question on: `terminal`

**Time:** about 35 minutes · **Topic:** Repository connection

## Scenario

Last week someone connected `starfleet/bridge-app` to Pipelines-as-Code in a hurry. Today pull request #1 (from `feature-hello` into `main`) has been open for hours, and no pipeline ever ran for it. The team wants its pull requests tested in the namespace `starfleet`, where the Secret `gitea-webhook-config` with the Gitea token and the webhook secret already waits.

## Your task

1. Find out why pull request #1 starts no PipelineRun. Look at the `Repository` objects in the whole cluster, the Secret in `starfleet`, the Gitea webhook of the repository, and the controller log. There is more than one fault.
2. Fix every fault so that events from `starfleet/bridge-app` start PipelineRuns in `starfleet`, using the Secret `starfleet/gitea-webhook-config` as it is.
3. Make Gitea send a new event for pull request #1, and get it tested.

## Constraints

- PipelineRuns for this repository must run in `starfleet`, through a `Repository` named `bridge-app` there.
- Keep the Secret `starfleet/gitea-webhook-config` and its keys as they are; adapt the `Repository` to it.
- Do not create PipelineRuns yourself, and do not change the files in the repository.

## Done when

- The only `Repository` for `http://gitea-http.gitea.svc.cluster.local:3000/starfleet/bridge-app` in the cluster is `bridge-app` in `starfleet`. It uses the Gitea provider at `http://gitea-http.gitea.svc.cluster.local:3000`, a token that Gitea accepts for `starfleet`, and a non-empty webhook secret.
- `starfleet/bridge-app` has an active webhook of type `gitea` that sends pull request events to `http://pipelines-as-code-controller.pipelines-as-code.svc.cluster.local:8080`.
- Pull request #1 has a PipelineRun created by Pipelines-as-Code in `starfleet` for its head commit. The run succeeded and its result `commit` is that head commit.
- Gitea shows the commit status `Pipelines as Code CI / pull-request` with the state `success` on that commit.
