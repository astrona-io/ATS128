# Solution: Start A Pipeline With An Incoming Webhook

Work the task yourself first. Running `astrona submit -c sections/section-030/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the incoming entry of the `Repository`; the Secret and that its value is not in the `Repository`; and a successful `release` run for the event type `incoming` with `environment` set to `staging`.

## Step 1: Read the pipeline

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/raw/.tekton/release.yaml?ref=main" | head -16
```

The annotation `on-event: "[incoming]"` limits `release` to incoming webhooks, and `on-target-branch: "[main]"` limits it to the branch `main`. The parameter `environment` takes `{{ environment }}`, a custom variable that the request must supply.

## Step 2: Create the Secret

```sh
kubectl -n starfleet create secret generic bridge-incoming --from-literal=secret=orbit-release-secret
```

## Step 3: Add the incoming webhook to the Repository

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
kubectl -n starfleet get repository bridge-app -o jsonpath='{.spec.incoming}{"\n"}'
```

## Step 4: Call the webhook

The controller listens on port 8080 of its Service. The path is `/incoming`. The query string names the `Repository`, the branch, the PipelineRun and the secret. The body sets the param:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -X POST -H 'Content-Type: application/json' \
  --data '{"params":{"environment":"staging"}}' \
  "http://pipelines-as-code-controller.pipelines-as-code.svc.cluster.local:8080/incoming?repository=bridge-app&branch=main&pipelinerun=release&secret=orbit-release-secret"
```

## Step 5: Check the run

```sh
kubectl get pipelineruns -n starfleet -l pipelinesascode.tekton.dev/original-prname=release \
  -L pipelinesascode.tekton.dev/event-type,pipelinesascode.tekton.dev/sha
tkn pac logs bridge-app -n starfleet -L
```

The run shows the event type `incoming` and `SUCCEEDED` `True`. The log of the last step prints `Releasing version ... to staging`.

## Step 6: Submit

```sh
astrona submit -c sections/section-030/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Write the secret into the `Repository` | The grader fails it: a `Repository` is readable by everyone who can read the namespace |
| Leave `environment` out of `params` | The request body cannot set it, so `{{ environment }}` stays unreplaced and the step fails |
| Call with `branch=develop` | The webhook may target only `main` |
| Push a commit to `main` | A push has the event type `push`, so `release` does not match |

## Common mistakes

- Using the name of the PipelineRun file instead of `metadata.name` in `pipelinerun=`. Use `release`.
- Sending the body without the header `Content-Type: application/json`.
- Misspelling the `Repository` name in the query. It is the name of the object, `bridge-app`.

## Practice on your own

- Call the webhook with a wrong secret and read the answer and the controller log.
- Add a second target branch to the entry and call it for that branch.
