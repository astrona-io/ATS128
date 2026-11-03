# Summary

A connected repository is configured in four places: the `Repository`, the ConfigMap `pipelines-as-code`, the Secret with the token and webhook secret, and the webhook on the Git server. Each setting has a scope, and the first question for a surprising behavior is which scope sets it.

## What you learned

The `Repository` holds the `url`, the `git_provider` block, `concurrency_limit`, `params`, `settings` and `incoming`. PipelineRuns are created in the namespace of the `Repository`, and one URL maps to one `Repository` in the cluster. The watcher records recent runs in `pipelinerun_status`, and `tkn pac list`, `describe` and `logs` read that history.

The ConfigMap `pipelines-as-code` holds installation-wide keys such as `application-name`, `default-max-keep-runs`, `max-keep-run-upper-limit`, `remote-tasks` and the error-snippet settings. A change affects new events only. `application-name` becomes the first part of the commit status context.

Each provider needs a way to deliver events and a token with enough rights. The webhook secret is checked on every request. A token is rotated by replacing the Secret with both keys, and the controller log shows whether the failure is a missing request, a bad signature, a rejected token or an unmatched URL.

`pipelinerun_provenance` chooses between the commit of the event (`source`) and the default branch (`default_branch`). The default lets a pull request change its own pipeline. The key facts to remember are these:

- A second `Repository` for the same URL leaves the repository without runs.
- A one-key Secret replaces the other key with nothing.
- `default_branch` tests a pull request with the reviewed pipeline.
- `/ok-to-test` allows a run to start. It is not a review of the template.

<!-- astrona:playground:destroy -->
