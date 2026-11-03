# Operate The Repository Connection

A connected repository is not a finished job. Over time a team changes the namespace a repository runs in, rotates the token, reads why a run did not start, changes the name of the commit status, and decides how much it trusts a pull request that edits the pipeline itself. All of these changes happen in four places: the `Repository` object, the global ConfigMap `pipelines-as-code`, the Secret with the provider token, and the webhook on the Git server.

This module teaches those four places in detail. You read the `Repository` field by field, change the global settings that apply to every repository, learn which token rights and webhook events each Git provider needs, and choose where Pipelines-as-Code reads the pipeline definitions from.

Keep one sentence in mind: **every setting has a scope: the cluster (ConfigMap), one repository (`Repository`), or one pipeline (annotation).** When a behavior surprises you, ask which scope sets it.

The module has four parts. **The Repository Object In Detail** covers each field of the `spec`, the namespace rule and the run history in the object. **Global Settings In The pipelines-as-code ConfigMap** covers the keys that apply to every repository and the `tkn pac` commands that read the installation. **Tokens, Webhook Events And The tkn pac Commands** covers the credentials and events each provider needs, how to rotate a token, and what a wrong token looks like. **Choose Where Pipeline Definitions Come From** covers `pipelinerun_provenance` and the `policy` setting. A graded lab follows the last part.

## Learning objectives

After this module you can:

- Name the fields of a `Repository` `spec` and say which ones are required for a webhook-based provider.
- Explain why PipelineRuns run in the namespace of the `Repository`, and why a second `Repository` for the same URL breaks matching.
- Read the run history that Pipelines-as-Code stores in the `Repository`.
- Change the application name, the default and maximum `max-keep-runs`, and the error-snippet settings in the ConfigMap `pipelines-as-code`.
- List the token rights and webhook events that GitHub, GitLab, Bitbucket and Gitea need.
- Rotate a provider token and recognize the symptoms of a wrong token.
- Set `pipelinerun_provenance` and explain why a pull request can change its own pipeline.

## Before you start

You need a connected repository in mind: a Secret with a token and a webhook secret, a `Repository` and a Git webhook. You should be able to read PipelineRun labels with `kubectl`.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `pipelines-as-code` | Pipelines-as-Code v0.52.0: controller, watcher and admission webhook |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.17.1 |
| Namespace `gitea` | Gitea (port 3000), the `tester` pod with `curl` and `jq`, and the token Secret `gitea-token` |
| Gitea repository `starfleet/bridge-app` | `.tekton/pull-request.yaml` and `.tekton/push.yaml` on `main` |
| Namespace `starfleet` | The `Repository` `bridge-app`, connected with the Secret `gitea-webhook-config` and a Gitea webhook |
| `tkn` and `tkn pac` on your PATH | The Tekton command-line tool 0.46.2 and the Pipelines-as-Code plugin 0.52.0 |

Every command runs against the playground cluster, and `kubectl` already points at it. The Gitea user `starfleet` and its password `starfleet-password` are lab-only credentials.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
