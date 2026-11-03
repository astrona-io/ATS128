# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Incoming webhooks

## Scenario

The `starfleet` team wants a release of `bridge-app` to start from a scheduler outside Git, without a new commit. The pipeline `release` already exists in `.tekton/release.yaml` on `main`. It matches only the event type `incoming`, and it takes the custom variable `{{ environment }}`. Nothing can start it yet, because the `Repository` `bridge-app` has no incoming webhook.

## Your task

1. Read `.tekton/release.yaml` on `main` and find the annotations that make it run for an incoming webhook, and the variable it needs.
2. Create the Secret `bridge-incoming` in `starfleet` with the key `secret`. Its value is a secret string of your choice with at least 12 characters.
3. Add an incoming webhook of the type `webhook-url` to the `Repository` `bridge-app`. It reads its secret from the Secret `bridge-incoming`, it may start runs only on `main`, and it lets the caller set the param `environment`.
4. Call the incoming webhook from the `tester` pod so that the pipeline `release` runs on `main` with `environment` set to `staging`.

## Constraints

- Do not change `.tekton/release.yaml`, and do not create PipelineRuns yourself.
- Keep the `Repository` `bridge-app` in the namespace `starfleet`, with its URL and its Secret references. Do not create a second `Repository`.
- Do not write the secret value into the `Repository`. It belongs in the Secret.

## Done when

- The `Repository` `bridge-app` has one incoming entry with the type `webhook-url`, the target `main`, the param `environment` and a reference to the Secret `bridge-incoming`.
- The Secret holds a value of at least 12 characters, and the value is not in the `Repository`.
- A PipelineRun created from `release` for the event type `incoming` succeeded. Its parameter `environment` is `staging`, and it ran on the head commit of `main`.
