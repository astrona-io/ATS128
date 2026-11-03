# The GitHub App

A GitHub App is an integration that an organization or user installs on chosen repositories. It has its own identity: an App ID and a private key. GitHub sends the events of the installed repositories to one webhook URL that belongs to the App, and the App reports results through the Checks API, which shows each run as a check on the pull request. This part explains how Pipelines-as-Code uses that identity and why it is the recommended way for GitHub.

## What the controller needs

For a GitHub App, the controller does not read a token from the `Repository`. It reads three values from one Secret named `pipelines-as-code-secret` in the namespace `pipelines-as-code`:

| Key | Content |
| --- | --- |
| `github-application-id` | The numeric ID of the App |
| `github-private-key` | The private key (PEM) that GitHub created for the App |
| `webhook.secret` | The secret GitHub uses to sign each webhook request |

<!-- astrona:playground:renew -->

The Secret belongs to the installation, not to a repository. Look at the namespace in the playground. It has no such Secret, because the playground uses Gitea:

```sh
kubectl -n pipelines-as-code get secrets
```

With the private key, the controller creates a short-lived installation token for each event, scoped to the repository that sent it. This is the main difference from a personal access token: nothing long-lived is tied to a person, and the token rights are the rights granted to the App.

## The Repository for a GitHub App

Because the App supplies the credentials, the `Repository` has only the URL. Save this as `repository-github-app.yaml`:

```yaml
apiVersion: pipelinesascode.tekton.dev/v1alpha1
kind: Repository
metadata:
  name: bridge-app-github
  namespace: starfleet
spec:
  url: "https://github.com/starfleet/bridge-app"
```

Ask the API server to validate it without creating it:

```sh
kubectl apply --dry-run=server -f repository-github-app.yaml
```

Then check that nothing was created:

```sh
kubectl -n starfleet get repositories.pipelinesascode.tekton.dev
```

Only `bridge-app` is listed. The admission webhook accepted the object, because the URL is valid and unique.

## What the App must be allowed to do

During creation, the App asks GitHub for permissions and events. For Pipelines-as-Code it needs to read repository contents and metadata, write checks and commit statuses, and read and write pull requests and issues for comments. It subscribes to the events pull request, push, issue comment, commit comment, check run and check suite. If a permission is missing, the controller can read the event but fails when it answers, so the log shows a failed API call.

## Creating the App with the plugin

The `tkn pac` plugin can create the App for you:

```sh
tkn pac bootstrap github-app --help
```

The help text lists the flags. The command opens a browser to GitHub, creates the App from a manifest with the right permissions and events, and stores the three values in the Secret. It needs a public address for the controller, so it cannot run in the playground.

## Checks and statuses

A GitHub App reports with the Checks API. A run appears as a check with a title, a summary and a link to the details. A failed step is quoted in the check output. Providers that use webhooks and tokens report with commit statuses instead, which carry only a state and a name. The checks are richer, and a reviewer can start a run again from the check.

## Common pitfalls

> [!WARNING]
> - **Putting the App key in the namespace of a repository.** The Secret is read from `pipelines-as-code`.
> - **Adding `git_provider` to a `Repository` for an App.** The App supplies the credentials, and a token in the object is not the App's.
> - **Installing the App on the wrong repositories.** Events arrive only for repositories where the App is installed.
> - **Losing the private key.** GitHub shows it once. Create a new key and update the Secret.
