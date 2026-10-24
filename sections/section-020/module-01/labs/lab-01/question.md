# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Event matching

## Scenario

The `starfleet` team opened pull request #1 to raise the shields version of `bridge-app`. Pipelines-as-Code is connected and works, yet the pull request was never tested. Someone wrote `.tekton/pull-request.yaml` from memory, and the team suspects the template itself.

## Your task

1. Find out why pull request #1 (from `feature-shields` into `main`) starts no PipelineRun. Read `.tekton/pull-request.yaml` on the pull request's branch.
2. Fix the template so that it runs for pull requests into `main`, and so that each run tests the commit of the event, not a fixed branch. There is more than one fault.
3. Commit the fix to the branch `feature-shields`, so that pull request #1 itself is tested with it.

## Constraints

- Keep the PipelineRun name `pull-request` and its tasks and steps. Change only what is wrong.
- The pull request must stay open and stay a pull request into `main`; do not retarget it or create a `master` branch.
- Do not write a commit SHA into the template, and do not create PipelineRuns yourself.

## Done when

- `.tekton/pull-request.yaml` on `feature-shields` keeps the name `pull-request`, matches `pull_request` events into `main`, and takes the parameter `revision` from `{{ revision }}` and `repo_url` from `{{ source_url }}` (or `{{ repo_url }}`).
- The current head commit of pull request #1 has a PipelineRun created by Pipelines-as-Code from `pull-request`, with the event type `pull_request`. It succeeded, and its result `commit` is that head commit.
- Gitea shows the commit status `Pipelines as Code CI / pull-request` with the state `success` on that commit.
