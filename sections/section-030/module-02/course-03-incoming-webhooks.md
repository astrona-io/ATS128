# Incoming Webhooks

Some runs should start without a Git event: a release started by a scheduler, a nightly build, a job started by another system. An incoming webhook gives such a caller a URL on the controller. The call names a repository, a branch and a template, and Pipelines-as-Code starts the run as if it were an event with the event type `incoming`.

## The incoming field

An incoming webhook is configured in the `Repository` under `incoming`:

| Field | What it does |
| --- | --- |
| `type` | `webhook-url`, the only type |
| `secret` | The Secret name and key that hold the shared secret the caller must send |
| `targets` | The branches the caller may start runs on |
| `params` | The names of custom variables the caller may set in the request body |

<!-- astrona:playground:renew -->

The template that answers it must match the event type `incoming`. The one in the playground, `.tekton/release.yaml`, has these annotations:

```yaml
annotations:
  pipelinesascode.tekton.dev/on-event: "[incoming]"
  pipelinesascode.tekton.dev/on-target-branch: "[main]"
```

Read it from the repository:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/raw/.tekton/release.yaml?ref=main"
```

Without `incoming` in the `Repository`, the template never runs, because nothing can produce its event.

## Configure the webhook

Create the Secret first. The value is the secret the caller will send:

```sh
kubectl -n starfleet create secret generic bridge-incoming --from-literal=secret=orbit-release-secret
```

Save this as `repository-bridge-app.yaml`:

```yaml
apiVersion: pipelinesascode.tekton.dev/v1alpha1
kind: Repository
metadata:
  name: bridge-app
  namespace: starfleet
spec:
  url: "http://gitea-http.gitea.svc.cluster.local:3000/starfleet/bridge-app"
  git_provider:
    type: gitea
    url: "http://gitea-http.gitea.svc.cluster.local:3000"
    secret:
      name: gitea-webhook-config
      key: provider.token
    webhook_secret:
      name: gitea-webhook-config
      key: webhook.secret
  incoming:
    - type: webhook-url
      secret:
        name: bridge-incoming
        key: secret
      targets:
        - main
      params:
        - environment
```

Apply it:

```sh
kubectl apply -f repository-bridge-app.yaml
```

Then check the result:

```sh
kubectl -n starfleet get repository bridge-app -o jsonpath='{.spec.incoming[0].targets}{"\n"}'
```

The command prints the list with `main`.

## Call the webhook

The endpoint is on the controller service, at the path `/incoming`. The call is a `POST` with query parameters and a JSON body. The `repository` is the name of the `Repository` object, `branch` is the branch to run on, `pipelinerun` is the name of the template, and `secret` is the shared secret. The body sets the custom variables that the `params` list allows:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -X POST \
  -H 'Content-Type: application/json' \
  --data '{"params":{"environment":"staging"}}' \
  "http://pipelines-as-code-controller.pipelines-as-code.svc.cluster.local:8080/incoming?repository=bridge-app&branch=main&pipelinerun=release&secret=orbit-release-secret"
```

Then check the run:

```sh
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/original-prname,pipelinesascode.tekton.dev/event-type
```

A `release` run appears with the event type `incoming`. The PipelineRun has the head commit of `main` as its revision, and the parameter `environment` is `staging`.

## What the controller checks

A call is refused or ignored when a check fails:

- The `repository` does not exist, or has no `incoming` entry.
- The `secret` does not equal the value in the Secret.
- The `branch` is not in `targets`.
- No template matches the event type `incoming` and the name in `pipelinerun`.

A parameter in the body that is not listed in `params` is not used. Only the listed names can be set by the caller, which limits what an outside system can change.

Treat the secret like a password. Because it travels in the URL, it can appear in logs of proxies and in shell history. Prefer an HTTPS address in front of the controller for real use, and rotate the secret by replacing the value in the Secret.

## Your mission: Start A Pipeline With An Incoming Webhook

You can now configure and call an incoming webhook. The graded lab gives you a repository with a `release` template that matches only incoming events, and a `Repository` without an `incoming` entry. You add the webhook and call it so that a release runs on `main` with the environment `staging`.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-128-playground-030-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS128.git -c sections/section-030/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-128-lab-030-02
astrona start ats-128-playground-030-02
```

## Common pitfalls

> [!WARNING]
> - **Using the wrong name for `repository`.** It is the name of the `Repository` object and not the URL.
> - **A branch that is not in `targets`.** The call is refused.
> - **A secret with a trailing newline.** A value created from a file can include the newline, and then it does not match what the caller sends. Create it with `--from-literal`.
> - **Sending a parameter that `params` does not list.** It is not used, and the variable stays as literal text.
