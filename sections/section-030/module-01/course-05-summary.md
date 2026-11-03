# Summary

What happens around a run decides whether CI is useful and safe. Pipelines-as-Code reports every run back to the Git provider, keeps the number of parallel runs under control, and lets only trusted people start runs.

## What you learned

The controller writes a `pending` status when it creates a run, and the watcher writes `success` or `failure` when the run finishes. The status name is the application name from the ConfigMap `pipelines-as-code` and the template name, such as `Pipelines as Code CI / lint`. A GitHub App shows check runs in the Checks tab; a GitHub webhook shows a pull request comment; Gitea and Forgejo show a commit status per template and a comment with the tasks and, for a failure, the end of the failed step's log. `tkn pac list`, `tkn pac describe` and `tkn pac logs` show the same from the cluster, and the namespace events and the controller log explain runs that never started.

`concurrency_limit` on the `Repository` sets how many of its PipelineRuns may run at the same time. The controller creates the runs as pending with the state `queued`, and the watcher starts them as slots become free, in alphabetical order for one event. `cancel-in-progress` cancels older runs of the same template for the same pull request or branch, and cannot be combined with a concurrency limit.

The controller checks the sender of every event. Owners, collaborators with write access, organization members and users listed in `OWNERS` on the default branch may run pipelines; for anyone else it writes a pending status that waits for `/ok-to-test`. The key facts to remember are these:

- `/ok-to-test` approves the current commit; `remember-ok-to-test` keeps the approval for later commits.
- `/retest` reruns failed runs; `/test <name>` forces one template.
- `OWNERS` grants the right to run pipelines without write access to the repository.
- The smallest `concurrency_limit` is `1`.

<!-- astrona:playground:destroy -->
