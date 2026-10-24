# Question

Solve this question on: `terminal`

**Time:** about 40 minutes · **Topic:** Access control

## Scenario

`cadet`, a new member of the community, forked `starfleet/bridge-app` and opened pull request #1 to explain the status line in the guide. The `starfleet` team expected Pipelines-as-Code to hold the pull request with a pending status until a maintainer approves it. Instead, nothing happened at all: no status, no comment, no PipelineRun. The team also wants `cadet`'s later pull requests to run without approval, but without giving `cadet` write access to the repository.

## Your task

1. Find out why Pipelines-as-Code ignores every event from `starfleet/bridge-app`. Start with the controller log and the events of the namespace `starfleet`.
2. Fix it, so that Gitea and Pipelines-as-Code use the same webhook secret.
3. As the owner `starfleet`, approve pull request #1 so that its pipeline runs, and check its commit status.
4. Trust `cadet` for later changes through the `OWNERS` file on `main`, so that new commits from `cadet` run without approval.

## Constraints

- Keep the `Repository` `bridge-app` and the Secret `gitea-webhook-config` in `starfleet` (you may change the Secret's values).
- Do not make `cadet` a collaborator, and do not change the PipelineRun templates.
- Do not create PipelineRuns yourself.

## Done when

- Pull request #1 from `cadet:docs-typo` is open, `starfleet` commented `/ok-to-test` on it, and its head commit has a successful PipelineRun of `pull-request` whose result `commit` is that head commit, with the status `Pipelines as Code CI / pull-request` = `success` in Gitea.
- `OWNERS` on `main` lists `cadet` under `approvers` or `reviewers`, and `cadet` is not a collaborator of `starfleet/bridge-app`.
- A new commit from `cadet` on `docs-typo` starts a successful PipelineRun without a new `/ok-to-test`. (The grader pushes this commit as `cadet`.)
