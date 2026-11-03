# Resolve Templates And Find Authoring Errors

Waiting for a push to find out that a template is wrong is slow. The plugin can render a template the way the controller does, on your machine, and the cluster tells you the rest. This part shows `tkn pac resolve` and lists the errors that authors make most often, with the place to read each one.

## Resolve a template

`tkn pac resolve` reads a template, embeds its Tasks and Pipelines, fills in variables that you give it and prints the PipelineRun that would be created. Save this as `pull-request.yaml`, a copy of the template on `main`:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/raw/.tekton/pull-request.yaml?ref=main" > pull-request.yaml
```

<!-- astrona:playground:renew -->

Then resolve it:

```sh
tkn pac resolve -f pull-request.yaml -p revision=main --no-secret
```

The command prints one PipelineRun. The `-p` flag gives a value for a variable, and `--no-secret` stops the command from asking for a token. Check three things in the output: the PipelineRun has `generateName`, the Tasks are embedded under `pipelineSpec`, and the variables you gave are replaced. A variable that you did not give stays as `{{ name }}`, which shows what a missing parameter looks like.

You can pipe the output to `kubectl apply --dry-run=server -f -` to ask the API server if the object is valid for the installed Tekton version.

## Errors and where to read them

| Symptom | Likely cause | Where to read it |
| --- | --- | --- |
| The pull request shows no run and no comment | The event did not match. `on-event` or `on-target-branch` is wrong | The controller log and `kubectl get pipelineruns` |
| A comment with a YAML error | The template is not valid YAML | The comment on the pull request, and `tkn pac resolve` locally |
| A comment that a Task cannot be found | A `taskRef` name has no matching file or annotation | The comment, and the list of files in `.tekton` |
| A parameter holds `{{ name }}` | The variable has no value for this event | `kubectl get pipelinerun -o yaml` |
| A run exists but the step fails on a clone | The revision or the credentials are wrong | `tkn pr logs` |
| No run for any event | Two PipelineRun templates have the same name | The controller log |

## Read a failed run

The cluster keeps the run and its pods until `max-keep-runs` removes them. List the runs and read the log of the newest one:

```sh
tkn pipelinerun list -n starfleet
tkn pipelinerun logs --last -n starfleet
```

When a step fails, the log ends with the error of that step. If the Pipelines-as-Code setting `error-log-snippet` is on, the last lines of the failed step are also placed in a comment on the pull request.

## A repeatable routine

When a run does not do what you expect, take these steps in order:

1. Resolve the template locally. Fix YAML and reference errors first.
2. Push, and check whether a PipelineRun was created with `kubectl get pipelineruns -n starfleet`.
3. If none was created, read the controller log for the event.
4. If one was created, read its parameters and the logs of its failed step.

Each step narrows the problem to one layer: the template, the matching, the creation or the steps.

## Common pitfalls

> [!WARNING]
> - **Resolving with a different revision.** Give `-p revision=` the value the event would have.
> - **Trusting a local resolve for remote Tasks.** The command fetches them from your machine's network, which can differ from the cluster's.
> - **Fixing the template without a new commit.** The controller reads the commit of the event. Push again, or send `/retest` on the pull request.
> - **Reading only the pull request.** Some failures appear only in the controller log.
