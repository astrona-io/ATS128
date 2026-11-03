# Check A Connected Repository End To End

A repository can look connected and still fail at one link: the webhook, the signature, the URL match, the token or the templates. This part gives a short routine that checks every link in the order an event travels, using one pull request. You can run it on any connected repository, and it is the fastest way to tell where a new connection is broken.

## The order of the links

An event passes these links. Each has one command that proves it:

| Link | What to prove | Where |
| --- | --- | --- |
| Webhook | Gitea sent the event to the controller Service on port 8080 | Gitea webhook list |
| Controller | The controller accepted it | `kubectl logs` of the controller |
| Repository | One `Repository` matches the URL | `kubectl get repositories -A` |
| Templates | A template matched the event | `kubectl get pipelineruns` |
| Run | The run succeeded | `Succeeded` condition |
| Status | Gitea shows the commit status | Gitea API |

<!-- astrona:playground:renew -->

## Prove the first links

Read the webhook from Gitea and the controller Service port. Both must agree on port 8080:

```sh
kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/hooks | jq -r ".[].config.url"'
kubectl -n pipelines-as-code get service pipelines-as-code-controller -o jsonpath='{.spec.ports[*].port}{"\n"}'
```

The webhook address ends with `:8080`, and the Service lists `8080` and `9090`. Port 8082 is the container port, and a webhook that targets it does not work, because the Service is the entry point.

Check that exactly one `Repository` has your URL:

```sh
kubectl get repositories.pipelinesascode.tekton.dev -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.spec.url}{"\n"}{end}'
```

## Prove the run and the status

Open a pull request that changes a file, then follow it. List the runs with the commit they tested, and compare the label with the head commit:

```sh
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/sha,pipelinesascode.tekton.dev/event-type
```

Read the statuses of that commit from Gitea. Replace `<SHA>` with the head commit:

```sh
kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/commits/<SHA>/statuses | jq -r ".[] | .context + \" \" + .status"'
```

A line such as `Pipelines as Code CI / pull-request success` closes the loop. If the run exists and the status is missing, the token cannot write statuses. If no run exists, go back one link at a time.

## Common pitfalls

> [!WARNING]
> - **Testing with a push when the template matches pull requests.** Use the event the template expects.
> - **Reading the delivery response in Gitea as proof.** The controller answers with HTTP 202 before it checks the signature, so a wrong secret shows only in the controller log.
> - **Checking the run but not the commit.** The `sha` label must equal the head commit of the pull request.
> - **Using a short host name for Gitea.** Use the full in-cluster name, or the URL in the event will not match.
