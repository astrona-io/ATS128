# Question

Solve this question on: `terminal`

**Time:** about 20 minutes · **Topic:** Concurrency

## Scenario

The `starfleet` cluster is small. Every pull request of `bridge-app` starts two pipelines, `lint` and `unit-test`, and they run at the same time. When several pull requests are busy, the node runs out of memory. The team wants the runs of `bridge-app` to run one after the other.

## Your task

1. Look at the two finished runs of pull request #1 and confirm from their start and completion times that they overlapped.
2. Change the `Repository` `bridge-app` in `starfleet` so that only one of its PipelineRuns runs at a time.
3. Push a new commit to the branch `feature-sensors`, so that pull request #1 runs both pipelines again under the new rule, and check that they did not overlap.

## Constraints

- Keep the templates `lint` and `unit-test` in `.tekton`, unchanged. Do not merge them.
- Keep the `Repository` named `bridge-app` with its URL, provider and Secret.
- Do not create PipelineRuns yourself.

## Done when

- The `Repository` `bridge-app` in `starfleet` has `spec.concurrency_limit: 1`.
- The current head commit of pull request #1 has a successful PipelineRun of `lint` and a successful PipelineRun of `unit-test`, and the `unit-test` run started no earlier than the `lint` run completed.
- Gitea shows `Pipelines as Code CI / lint` and `Pipelines as Code CI / unit-test` with the state `success` on that commit.
