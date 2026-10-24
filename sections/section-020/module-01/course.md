# Write Pipelines In The .tekton Directory

Once a repository is connected, every push and every pull request reaches Pipelines-as-Code. The next question is what should run for each one. A pull request into `main` may need the full test suite, a push to `main` may need a build and a release, and a change that only touches the documentation may need nothing at all. The answer lives in the `.tekton` folder: each PipelineRun there carries annotations that say which events and branches it is for.

This module teaches how to write those PipelineRuns. You learn how Pipelines-as-Code reads the folder, how dynamic variables such as `{{ revision }}` put the event's commit into the run, and how the matching annotations choose the PipelineRuns for an event. You also learn the tools for harder cases (CEL expressions and path changes) and how to keep old runs from piling up.

Keep one sentence in mind: **every file in `.tekton` is a template, and its annotations are a filter.** A PipelineRun runs only when the event passes its filter.

The module has three parts. **The .tekton Directory And Dynamic Variables** explains how the folder is read, what Pipelines-as-Code changes in a template before it creates the run, and how to check the result. **Match Events And Branches With Annotations** covers `on-event` and `on-target-branch`, push and pull request events, branch globs and tags. A graded lab follows the second part. **CEL Expressions, Path Changes And Cleanup** covers `on-cel-expression`, `on-path-change`, remote tasks, duplicate names and `max-keep-runs`.

## Learning objectives

After this module you can:

- Explain where Pipelines-as-Code reads `.tekton` from, and what it does with each file.
- Use dynamic variables such as `{{ revision }}`, `{{ repo_url }}`, `{{ source_url }}` and `{{ target_branch }}` in a PipelineRun.
- Match PipelineRuns to `push` and `pull_request` events and to branches, with globs and tags.
- Write a CEL expression and say which annotations it overrides.
- Run a PipelineRun only when certain paths change.
- Keep a fixed number of runs with `max-keep-runs`, and avoid duplicate PipelineRun names.

## Before you start

You need a connected repository in mind: a `Repository` object, a token and a webhook, and you should know that the pipelines-as-code-controller creates PipelineRuns in the namespace of the `Repository`. You also need to read a Tekton `PipelineRun` with `pipelineSpec`, parameters and results.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `pipelines-as-code` | Pipelines-as-Code v0.52.0: controller, watcher and admission webhook |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.17.1 |
| Namespace `gitea` | Gitea (port 3000), the `tester` pod with `curl` and `jq`, and the token Secret `gitea-token` |
| Gitea repository `starfleet/bridge-app` | `.tekton/pull-request.yaml` (pull requests into `main`) and `.tekton/push.yaml` (pushes to `main`) on `main` |
| Namespace `starfleet` | The `Repository` `bridge-app`, already connected with the Secret `gitea-webhook-config` and a Gitea webhook |
| `tkn` and `tkn pac` on your PATH | The Tekton command-line tool 0.46.2 and the Pipelines-as-Code plugin 0.52.0 |

Every command runs against the playground cluster, and `kubectl` already points at it. The Gitea user `starfleet` and its password `starfleet-password` are lab-only credentials.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
