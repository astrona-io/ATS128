# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Repository settings

## Scenario

The `starfleet` team opened pull request #1 from the branch `feature-tamper` into `main` of `bridge-app`. The branch bumps the application version, but it also changes `.tekton/pull-request.yaml`: its test step now always fails. Pipelines-as-Code is connected and works. It ran the pipeline from the pull request's own branch, so the pull request shows a failed status for a reason that has nothing to do with the code. The team decides that pull requests must be tested with the pipeline definition on `main`, which only reviewed changes can reach.

## Your task

1. Read `.tekton/pull-request.yaml` on `main` and on `feature-tamper`, and confirm that the branch changed the test step.
2. Change the `Repository` `bridge-app` so that Pipelines-as-Code reads the PipelineRun definitions from the default branch of the repository for every event.
3. Start the pull request pipeline again for the current head commit of pull request #1, so that the new run uses the definition from `main`.

## Constraints

- Do not edit anything on the branch `feature-tamper`, and do not close or retarget pull request #1.
- Keep the `Repository` `bridge-app` in the namespace `starfleet`, with its URL and its Secret references. Do not create a second `Repository`.
- Do not create PipelineRuns yourself.

## Done when

- The `Repository` `bridge-app` has `spec.settings.pipelinerun_provenance` set to `default_branch`, and it still points at `starfleet/bridge-app` with the Secret `gitea-webhook-config`.
- `.tekton/pull-request.yaml` on `feature-tamper` still holds the changed test step.
- The newest PipelineRun that Pipelines-as-Code created for the head commit of pull request #1 succeeded, and it does not contain the changed test step.
- Gitea shows the commit status `Pipelines as Code CI / pull-request` with the state `success` on that commit.
