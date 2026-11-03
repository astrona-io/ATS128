# Parameters, Secrets, Tasks And Resolving

A template in `.tekton` rarely stays the same for every repository, every branch and every environment. The target of a deploy, the log level or a token for a registry differ. This module teaches how to feed values into a template without writing them into it, how to hand a Secret to a run safely, where the Tasks and Pipelines of a template can come from, and how to look at a template the way the controller sees it before you push it.

Keep one sentence in mind: **a template describes the steps, and the Repository, the event and the cluster supply the values.** When a value is wrong, find which of the three supplied it.

The module has four parts. **Custom Parameters On The Repository** covers `params`, filters and the full list of dynamic variables, and a graded lab follows it. **Secrets And The Git Provider Token In A Run** covers `secret_ref` and the `git_auth_secret` variable. **Local And Remote Tasks And Pipelines** covers the `task` and `pipeline` annotations, where the definitions are fetched from and the `remote-tasks` switch. **Resolve Templates And Find Authoring Errors** covers `tkn pac resolve` and the usual errors of a template.

## Learning objectives

After this module you can:

- Define custom parameters in the `Repository` and use them as `{{ name }}` in a template.
- Limit a parameter to certain events or branches with a CEL filter.
- Name the dynamic variables of an event and say where each value comes from.
- Pass a Secret value to a run with `secret_ref`, and use `git_auth_secret` for a private clone.
- Use a Task or Pipeline from the `.tekton` folder, a URL or a catalog, and say which settings allow it.
- Resolve a template with `tkn pac resolve` and read the errors that a bad template gives.

## Before you start

You need to know how the `.tekton` folder is read, how `on-event` and `on-target-branch` select a template, and what the `Repository` object holds. You also need to read a Tekton `PipelineRun` with parameters.

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
