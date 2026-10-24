# Question

Solve this question on: `terminal`

**Time:** about 35 minutes · **Topic:** Event matching

## Scenario

The `starfleet` team wants a build of `bridge-app` for every push to `main` and to every release branch (`release-1.0`, `release-1.1`, and so on), and nothing for pushes to feature branches. The `.tekton` folder on `main` has a push pipeline for this, but no push has ever started it. The cluster also fills up with old runs, so the team wants only the three newest runs of the push pipeline kept.

## Your task

1. Find out why a push to `main` starts no PipelineRun `push`. Read every file in `.tekton` on `main`. There is more than one fault.
2. Fix the `.tekton` folder on `main` so that the PipelineRun `push` runs for pushes to `main` and to every `release-*` branch, and for no other branch.
3. Make Pipelines-as-Code keep at most three finished runs of `push`.

## Constraints

- Keep the PipelineRun names `push` and `pull-request`, and keep `.tekton/pull-request.yaml` as it is.
- Work on `main`. Keep the branches `release-1.0` and `feature-engines`.
- Do not create PipelineRuns yourself.

## Done when

- `.tekton` on `main` has no two PipelineRuns with the same name; exactly one file defines `push`, and it sets `pipelinesascode.tekton.dev/max-keep-runs: "3"`. `pull-request` is still there.
- A new commit on `main` and a new commit on `release-1.0` each get a successful PipelineRun `push` and the commit status `Pipelines as Code CI / push` = `success` in Gitea. A new commit on `feature-engines` gets no PipelineRun. (The grader makes these commits.)
- After at least four pushes, at most three PipelineRuns of `push` are kept.
