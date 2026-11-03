# Find Out Why A Run Did Not Start

The most common report is "I pushed and nothing happened". The cause is in one of five places, and each has a place to read. Work from the Git server toward the cluster and stop at the first step that did not happen.

## The chain of a run

An event passes through these steps, and a run exists only if all of them succeed:

1. The Git server sends a webhook request.
2. The request reaches the controller, and the signature is valid.
3. A `Repository` matches the URL, and the user is allowed.
4. The `.tekton` files are read, and a template matches the event.
5. The template resolves, and the PipelineRun is created and scheduled.

<!-- astrona:playground:renew -->

## Step 1 and 2: the webhook

In Gitea, the page of the webhook lists recent deliveries with their response codes. Through the API, list the webhook and read its settings:

```sh
kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/hooks | jq ".[] | {id, active, events, url: .config.url}"'
```

Check that the webhook is active, that the url is the controller service, and that the events include what you did. Then read the controller log for the time of your push:

```sh
kubectl -n pipelines-as-code logs deploy/pipelines-as-code-controller --since=5m
```

No line for your push means the request did not arrive. A line about the signature or the webhook secret means the secret differs on the two sides.

## Step 3: the Repository

List the `Repository` objects of the cluster and compare the `url` with the repository:

```sh
kubectl get repositories.pipelinesascode.tekton.dev -A
```

A missing object, a different URL or a second object for the same URL explains a run that does not start. For a pull request from a user without rights, the controller waits for `/ok-to-test`.

## Step 4: the templates

Read the templates on the branch of the event and check `on-event` and `on-target-branch`. A misspelled event name, a branch that is not the target of the pull request, or a CEL expression that is false for this event all give no run. A repeated name in `.tekton` stops every run. Render a template with the values of the event:

```sh
tkn pac resolve -f pull-request.yaml -p revision=main --no-secret
```

## Step 5: the PipelineRun

If a run was created but did not run, read the objects in the namespace:

```sh
kubectl get pipelineruns -n starfleet
kubectl get events -n starfleet --sort-by=.lastTimestamp
tkn pac describe bridge-app -n starfleet
```

A run that waits is queued by `concurrency_limit`. A run that fails at once may have a bad reference or a missing ServiceAccount, which the events show. `tkn pac describe` lists the recent runs of the repository and their results.

## Break something and read it

In the playground, break a template on a branch in two ways, one at a time: write `on-event: "[pull-request]"` instead of `pull_request`, and add a second PipelineRun with the same `metadata.name`. For each, push, open a pull request and use the steps above to find the reason. The first gives no run, and the controller log has the reason. Read the log text of your release instead of searching for a fixed phrase.

## Common pitfalls

> [!WARNING]
> - **Reading only the pull request.** Several failures are written only to the controller log.
> - **Checking the cluster first.** If the webhook did not send the event, nothing in the cluster can show it.
> - **Fixing the template and not pushing.** The controller reads the commit of the event. Push again or comment `/retest`.
> - **Assuming a queued run is broken.** A run that waits for `concurrency_limit` starts when a slot is free.
