# The Repository Object In Detail

The `Repository` is the only object you create for Pipelines-as-Code. Every setting that belongs to one repository sits in it: where the runs execute, how to call the Git provider, how many runs may be active and which extra variables the templates may use. This part reads the object field by field, so that you can tell which field to change when a behavior is wrong. It also shows the run history that the object keeps.

## The fields of the spec

A `Repository` is a namespaced custom resource of the group `pipelinesascode.tekton.dev`. Its short name is `repo`. The `spec` has these fields:

| Field | What it does |
| --- | --- |
| `url` | The address of the repository. It must equal the address in the webhook payload |
| `git_provider.type` | The provider: `github`, `gitlab`, `gitea`, `bitbucket-cloud` or `bitbucket-datacenter` |
| `git_provider.url` | The API address of the provider. Needed for self-hosted servers |
| `git_provider.user` | The user name, needed only by Bitbucket Cloud |
| `git_provider.secret` | The Secret name and key that hold the provider token |
| `git_provider.webhook_secret` | The Secret name and key that hold the webhook secret |
| `concurrency_limit` | The number of PipelineRuns of this repository that may run at the same time |
| `params` | Custom variables for the templates, with an optional `filter` and a `secret_ref` |
| `settings` | Behavior switches such as `pipelinerun_provenance` and `policy` |
| `incoming` | Incoming webhooks that start runs without a Git event |

With a GitHub App you leave out `git_provider`, because the App supplies the credentials. With every other provider the token and the webhook secret are required.

<!-- astrona:playground:renew -->

Read the object of your playground:

```sh
kubectl -n starfleet get repository bridge-app -o yaml
```

The `spec` holds the `url` and the `git_provider` block you created. Near the end of the output, a list named `pipelinerun_status` holds one entry for each recent run. The same object is also reachable by its short name:

```sh
kubectl -n starfleet get repo
```

## The namespace rule

Pipelines-as-Code creates the PipelineRuns of an event in the namespace of the `Repository` that matched the event. That makes the namespace the place for everything a run needs: Secrets, ServiceAccounts, ConfigMaps and the resource quota. A team that owns a repository gets a namespace, and the `Repository` in it.

The second rule is that a repository URL maps to exactly one `Repository` in the whole cluster. The admission webhook of Pipelines-as-Code refuses a second object with the same URL. If an old object exists in another namespace, the controller finds two matches and cannot decide, so it runs nothing. The first command below lists every `Repository` of the cluster with its namespace and URL:

```sh
kubectl get repositories.pipelinesascode.tekton.dev -A
```

One line is listed in a healthy cluster for each connected repository. Two lines with the same URL are the cause of a repository that suddenly starts nothing.

## The run history in the object

After each run, the pipelines-as-code-watcher adds an entry to `pipelinerun_status` and keeps the newest ones. An entry holds the PipelineRun name, the commit SHA, the event type, the target branch, the start and completion times and the result. The `tkn pac` plugin reads this history to show a repository's runs. Push a commit and look again:

```sh
kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password -X POST \
  -H "Content-Type: application/json" \
  --data "{\"branch\":\"main\",\"message\":\"Add a note\",\"content\":\"$(printf "note\n" | base64)\"}" \
  "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/contents/docs/note-$(date +%s).md" | jq -r .commit.sha'
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/original-prname
kubectl -n starfleet get repository bridge-app -o jsonpath='{range .pipelinerun_status[*]}{.pipelineRunName} {.event_type} {.target_branch}{"\n"}{end}'
```

The first command prints the SHA of the new commit. Gitea sends a `push` event, and a `push` PipelineRun appears with the label `original-prname` set to `push`. When the run has been recorded, the third command prints one line for each run in the history. The history is not a log of everything: it is limited in length, and the PipelineRuns themselves are the source of truth.

## Changing the object safely

Pipelines-as-Code validates every change to a `Repository` through its admission webhook. The webhook checks the URL scheme (it must be `http` or `https`) and refuses a duplicate URL. A change to `git_provider.secret` takes effect at the next event, because the controller reads the Secret for each event. The change of a `Repository` never restarts a run that is already running.

Save this as `repository-bridge-app.yaml`. It is the same object with one more field, a limit of two running PipelineRuns:

```yaml
apiVersion: pipelinesascode.tekton.dev/v1alpha1
kind: Repository
metadata:
  name: bridge-app
  namespace: starfleet
spec:
  url: "http://gitea-http.gitea.svc.cluster.local:3000/starfleet/bridge-app"
  concurrency_limit: 2
  git_provider:
    type: gitea
    url: "http://gitea-http.gitea.svc.cluster.local:3000"
    secret:
      name: gitea-webhook-config
      key: provider.token
    webhook_secret:
      name: gitea-webhook-config
      key: webhook.secret
```

Apply it:

```sh
kubectl apply -f repository-bridge-app.yaml
```

Then check the result:

```sh
kubectl -n starfleet get repository bridge-app -o jsonpath='{.spec.concurrency_limit}{"\n"}'
```

The command prints `2`. A `kubectl apply` of a file that leaves a field out removes that field, so always start from the current object (`kubectl get repository bridge-app -o yaml`) when you change one field in an existing system.

You now know every field of the `Repository`, the namespace rule and where the run history lives. Settings that apply to all repositories at once do not live here; they live in a ConfigMap, which is the next topic.

## Common pitfalls

> [!WARNING]
> - **A `url` that differs from the webhook payload.** A trailing slash, `http` instead of `https` or another host name means no event finds the `Repository`.
> - **A second `Repository` for the same URL in another namespace.** The admission webhook refuses a new one, but an old one that was created before can stay. Check with `-A`.
> - **A Secret in another namespace.** The Secret named in `git_provider` must be in the namespace of the `Repository`.
> - **Applying a partial file.** `kubectl apply` of a file that lacks `git_provider` removes the connection data. Edit the current object instead.
