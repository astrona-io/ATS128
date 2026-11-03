# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Parameters

## Scenario

The `starfleet` team added a `report` step to `.tekton/pull-request.yaml` on `main` of `bridge-app`. The step prints two values, `deploy_target` and `log_level`, and fails when a value was never replaced. Pull request #1 from `feature-params` into `main` ran the pipeline, and the `report` step failed. The team does not want to write the values into the template, because other repositories will use the same template with other values.

## Your task

1. Read the `report` step in `.tekton/pull-request.yaml` on `main` and the log of the failed run, and find which two variables have no value.
2. Define both values on the `Repository` `bridge-app`: `deploy_target` is `shuttle-bay` and `log_level` is `debug`.
3. Start the pull request pipeline again for the current head commit of pull request #1.

## Constraints

- Do not change `.tekton/pull-request.yaml` on `main` or on `feature-params`. The template must keep using `{{ deploy_target }}` and `{{ log_level }}`.
- Keep the `Repository` `bridge-app` in the namespace `starfleet`, with its URL and its Secret references. Do not create a second `Repository`.
- Do not create PipelineRuns yourself, and keep pull request #1 open into `main`.

## Done when

- The `Repository` `bridge-app` has the params `deploy_target` with the value `shuttle-bay` and `log_level` with the value `debug`.
- The template on `main` still takes both values from the variables.
- The newest PipelineRun that Pipelines-as-Code created for the head commit of pull request #1 succeeded, and its parameters `deploy_target` and `log_level` hold the two values.
- Gitea shows the commit status `Pipelines as Code CI / pull-request` with the state `success` on that commit.
