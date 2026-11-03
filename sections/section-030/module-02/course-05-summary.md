# Summary

A run starts because an event matched a template. A comment and an incoming webhook are events too. When a run does not start, the work is to find the first step of the chain that did not happen.

## What you learned

Comments that start with `/retest`, `/test`, `/cancel` and `/ok-to-test` control the runs of a pull request, and a name after the command selects one template. `/ok-to-test` lets a pull request from a user without rights start runs, and only an allowed user can write it. A template with `on-comment` starts from a comment that matches its regular expression, and `{{ trigger_comment }}` holds the text, which is user input and must be passed through an environment variable.

An incoming webhook is configured with `incoming` in the `Repository`: a type, a Secret for the shared secret, the target branches and the custom variables the caller may set. The call is a `POST` to the controller at `/incoming` with the query parameters `repository`, `branch`, `pipelinerun` and `secret`, and the template must match the event type `incoming`.

A missing run is found by checking, in order, the webhook delivery, the controller log, the `Repository` match, the template matching, and the PipelineRuns and events in the namespace. The key facts to remember are these:

- A comment-only template runs only when its expression matches.
- The caller of an incoming webhook can set only the variables listed in `params`.
- A secret created from a file can carry a newline.
- Work from the Git server toward the cluster and stop at the first missing step.

<!-- astrona:playground:destroy -->
