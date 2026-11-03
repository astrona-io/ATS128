# Run A Template From A Comment

The commands in the last part restart pipelines that match the pull request. A template can also be written to run only when a certain comment is written. This is useful for actions that should not run on every pull request: a long test suite, a deploy to a preview environment, or a report on request.

## The on-comment annotation

The annotation `pipelinesascode.tekton.dev/on-comment` holds a regular expression. The controller starts the template when a comment on a pull request matches it. Here is the template that the playground has in `.tekton/status-report.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: status-report
  annotations:
    pipelinesascode.tekton.dev/on-comment: "^/status-report"
    pipelinesascode.tekton.dev/max-keep-runs: "3"
spec:
  params:
    - name: comment
      value: "{{ trigger_comment }}"
```

The expression `^/status-report` matches a comment that starts with `/status-report`. The anchor matters: without it, the text could match anywhere in a long comment.

<!-- astrona:playground:renew -->

Open a pull request and write the comment `/status-report now` as `starfleet`:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  -X POST -H 'Content-Type: application/json' --data '{"body":"/status-report now"}' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/issues/1/comments
```

Then list the runs and read the log of the new one:

```sh
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/original-prname
tkn pipelinerun logs --last -n starfleet
```

The step prints `The comment was: /status-report now`.

## The trigger_comment variable

`{{ trigger_comment }}` holds the full text of the comment that started the run. A template can use it to read an argument, such as an environment name. Be careful: the text comes from a user. If you put it straight into a script, a comment with shell syntax runs as a command. The template above passes it through an environment variable, so the shell reads it as data:

```yaml
env:
  - name: COMMENT
    value: $(params.comment)
script: |
  #!/bin/sh
  echo "The comment was: $COMMENT"
```

Never write `$(params.comment)` or `{{ trigger_comment }}` directly into the script text.

## Comment templates and branch matching

A template with `on-comment` does not need `on-event`. Add `on-target-branch` if the template should apply only to pull requests into certain branches. A template that has both `on-event` and `on-comment` runs for the event and for the comment. Keep comment-only templates separate, so that their purpose is clear.

## Where comment templates run

A comment template runs with the files of the pull request, or with the files of the default branch if the Repository uses the default branch as the source. The user who writes the comment must be allowed to start runs. In practice a maintainer writes the comment after a review, which makes it a safe way to start an expensive pipeline.

## Common pitfalls

> [!WARNING]
> - **No anchor in the expression.** `/status-report` without `^` matches any comment that mentions it.
> - **Writing the comment text into the script.** A comment is user input. Pass it through an environment variable.
> - **Expecting the template to run for every pull request.** A comment-only template runs only when the comment matches.
> - **Using a comment for a deploy without a limit on who can comment.** Anyone allowed to comment can start it.
