# Global Settings In The pipelines-as-code ConfigMap

Some behavior is not a property of one repository. The name shown in a commit status, how many finished runs are kept, and how a failed step is quoted in a pull request are decisions for the whole installation. Pipelines-as-Code keeps them in one ConfigMap named `pipelines-as-code` in the namespace `pipelines-as-code`. This part reads that ConfigMap, changes one key and shows how to confirm what the installation is running.

## What the ConfigMap holds

Read it:

```sh
kubectl -n pipelines-as-code get configmap pipelines-as-code -o yaml
```

<!-- astrona:playground:renew -->

The `data` section lists the keys. These are the ones you meet most often:

| Key | What it controls |
| --- | --- |
| `application-name` | The name used in the commit status. The default is `Pipelines as Code CI` |
| `max-keep-run-upper-limit` | The largest value a pipeline may set with `max-keep-runs` |
| `default-max-keep-runs` | The number of runs kept when a pipeline sets no `max-keep-runs` |
| `auto-configure-new-github-repo` | Whether a new GitHub repository is configured automatically |
| `secret-auto-create` | Whether the controller creates a Secret with the provider token for each run |
| `remote-tasks` | Whether tasks and pipelines may be fetched from remote locations |
| `hub-url` | The catalog address used for the `task` annotation with a short name |
| `error-log-snippet` | Whether the last lines of a failed step are added to the pull request |
| `error-log-snippet-number-of-lines` | How many lines the snippet has |
| `tekton-dashboard-url` | The base address used to build links to the Tekton Dashboard |

A key that is missing uses the default of the release. The file in the installation is the reference for your version, so read the live object before you rely on a default from memory.

## The commit status name

When a run ends, Pipelines-as-Code sets a commit status on the commit. The status context is the application name followed by a slash and the PipelineRun name. With the default, a run of `pull-request` shows as `Pipelines as Code CI / pull-request`. Teams that run more than one CI system change `application-name` so that the source of the status is clear.

Read the current value:

```sh
kubectl -n pipelines-as-code get configmap pipelines-as-code -o jsonpath='{.data.application-name}{"\n"}'
```

Save this as `patch-application-name.yaml`:

```yaml
data:
  application-name: "Starfleet CI"
```

Apply it:

```sh
kubectl -n pipelines-as-code patch configmap pipelines-as-code --type merge --patch-file patch-application-name.yaml
```

Then check the result:

```sh
kubectl -n pipelines-as-code get configmap pipelines-as-code -o jsonpath='{.data.application-name}{"\n"}'
```

The command prints `Starfleet CI`. The controller watches the ConfigMap, so the next run uses the new name without a restart. Push a commit to the repository and read the status of the new commit from Gitea:

```sh
SHA=$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password -X POST \
  -H "Content-Type: application/json" \
  --data "{\"branch\":\"main\",\"message\":\"Rename status\",\"content\":\"$(printf "x\n" | base64)\"}" \
  "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/contents/docs/status-$(date +%s).md" | jq -r .commit.sha')
echo "$SHA"
sleep 30
kubectl -n gitea exec deploy/tester -- sh -c "curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/commits/$SHA/statuses | jq -r '.[].context'"
```

The context starts with `Starfleet CI`. Statuses that were set before the change keep the old name, because Gitea stores them as text.

## Limits for max-keep-runs

A pipeline can ask to keep only the newest runs with the annotation `pipelinesascode.tekton.dev/max-keep-runs`. Without a limit, the PipelineRuns of every event stay in the namespace and fill it. Two keys control this:

- `default-max-keep-runs` applies when a pipeline has no annotation. If it is not set, nothing is cleaned up by default.
- `max-keep-run-upper-limit` caps what a pipeline may ask for. A pipeline that asks for more gets the cap.

A platform team sets both, so that a repository cannot keep ten thousand runs in its namespace.

## Reading what the installation runs

Two read-only sources tell you the state of the installation. The ConfigMap `pipelines-as-code-info` holds the installed version and the controller address:

```sh
kubectl -n pipelines-as-code get configmap pipelines-as-code-info -o jsonpath='{.data.version}{"\n"}'
```

The command prints the release, `v0.52.0` in the playground. The plugin shows the same information together with the Git provider setup:

```sh
tkn pac info install
```

The output names the installed version and the controller URL. It is the first command to run when you work on an installation you do not know.

## What a change does not do

A key of the ConfigMap changes the behavior for new events. It does not change the PipelineRuns that exist. A change to `remote-tasks` turns remote tasks off for every repository at once, so a pipeline with the `task` annotation for a remote location then fails to resolve. Because the scope is the whole installation, change one key at a time and test with one run.

## Common pitfalls

> [!WARNING]
> - **Replacing the whole ConfigMap.** `kubectl apply` of a file with only one key removes the other keys. Use `kubectl patch` or edit the live object.
> - **Expecting old statuses to change.** The application name is written into each status at the time of the run.
> - **Setting `max-keep-run-upper-limit` below `default-max-keep-runs`.** The default is then capped, which is confusing to debug. Keep the default at or below the upper limit.
> - **Treating the ConfigMap as a place for per-repository values.** A value for one repository belongs in the `Repository`.
