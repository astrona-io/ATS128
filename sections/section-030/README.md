# Section 030: Pull Request Status, Concurrency And Access Control

Once pipelines run for every pull request, three new questions come up. How does the author of a pull request see the result? What stops the cluster from running dozens of pipelines when many commits arrive at once? And who is allowed to start a pipeline at all, when a pipeline runs the pull request's own code with access to the team's Secrets? This section answers all three.

You first follow a run's result back to the Git provider: commit statuses and comments on Gitea, check runs with a GitHub App, comments with a GitHub webhook, and the `tkn pac` commands that show the same from the cluster. Then you limit the runs of a repository with `concurrency_limit`, watch the queue, and learn when to cancel runs instead. Last, you learn the access rules, trust a contributor with the `OWNERS` file, and approve a pull request with `/ok-to-test`.

**Topic covered:** Status, concurrency and access control

## What you will learn

- How Pipelines-as-Code reports runs: statuses, comments, check runs, and log snippets for failures.
- Reading the runs of a repository with `tkn pac list`, `tkn pac describe` and `tkn pac logs`.
- `concurrency_limit`, the queue, the `state` label and the order in which queued runs start.
- `cancel-in-progress` and its limits.
- Who may run pipelines: owners, collaborators, organization members and the `OWNERS` file.
- The GitOps commands `/ok-to-test`, `/retest`, `/test` and `/cancel`.

## The learning path

The section has one module. It has a landing page, three short parts, a graded lab right after the part it tests, and a summary. The module also has its own playground, a cluster where you can explore freely, and the landing page starts it for you.

### 1. Control How Pipeline Runs Report, Queue And Start

The module starts at its landing page, which also launches the playground. The playground runs Tekton Pipelines, Pipelines-as-Code and a Gitea server with a second user, `cadet`, and `starfleet/bridge-app` is connected with two pull request pipelines, `lint` and `unit-test`.

1. How Pipelines-as-Code Reports Status
2. Queue Runs With concurrency_limit, followed by the lab **Queue Pull Request Runs With concurrency_limit**
3. Control Who Can Run Pipelines
4. Summary

## Section capstone: Gate An Outside Contributor's Pull Request

The capstone is one graded scenario that combines the whole module. The user `cadet` opened a pull request from a fork, and nothing happened: not even the pending status that should ask for an approval. The webhook secret differs between Gitea and the cluster, so every event is refused. Fix the secret, approve the pull request with `/ok-to-test`, and trust `cadet` for later pull requests with the `OWNERS` file instead of write access. The grader then pushes a new commit as `cadet` and expects it to run without approval. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS128.git -c sections/section-030/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-128-capstone-030
```
