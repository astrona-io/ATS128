# Cancel Runs That Are No Longer Needed

A developer pushes three commits to a pull request in two minutes. Each push starts a run, and the first two test commits that nobody will merge. They use cluster capacity and show old results. Pipelines-as-Code can cancel such runs. This part shows the setting, where it applies and why it cannot be combined with a concurrency limit.

## The two ways to turn it on

Cancel-in-progress can be set for the whole installation or for one template. The ConfigMap `pipelines-as-code` has two keys, both off by default:

| Key | Effect |
| --- | --- |
| `enable-cancel-in-progress-on-pull-requests` | A new push to a pull request cancels the running pipelines of the older commit |
| `enable-cancel-in-progress-on-push` | A new push to a branch cancels the running pipelines of the older commit |

Read the current values:

<!-- astrona:playground:renew -->

```sh
kubectl -n pipelines-as-code get configmap pipelines-as-code -o jsonpath='{.data.enable-cancel-in-progress-on-pull-requests}{" "}{.data.enable-cancel-in-progress-on-push}{"\n"}'
```

Both print `false` in a fresh installation. A single template can opt in with an annotation:

```yaml
metadata:
  name: pull-request
  annotations:
    pipelinesascode.tekton.dev/cancel-in-progress: "true"
```

## Try it

Open a pull request with the template above on its branch, and push a second commit while the first run is going. Then list the runs with their commits:

```sh
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/sha
```

The run of the first commit shows a cancelled reason, and the run of the second commit goes on. The cancelled run is not deleted. Its logs stay until `max-keep-runs` removes it.

## What it does not do

Cancel-in-progress looks at runs of the same template on the same pull request or branch. It does not cancel runs of other templates, and it does not touch runs that already finished. A manual `/cancel` comment still works for any run.

## Not with concurrency_limit

The two features pull in opposite directions. A concurrency limit keeps every run and queues it. Cancel-in-progress drops older runs. Pipelines-as-Code does not allow both on the same repository, so choose one. Use the queue when every commit must be tested, as for push builds that publish. Use cancel when only the newest commit matters, as for pull request checks.

## Common pitfalls

> [!WARNING]
> - **Cancelling push runs that publish artifacts.** A cancelled publish can leave a half-finished release.
> - **Combining the setting with `concurrency_limit`.** They cannot be used together.
> - **Expecting the old status to turn green.** The old commit keeps a failed or cancelled status. The new commit has the result that counts.
> - **Setting it for the whole installation without telling teams.** Teams that rely on every commit being tested will lose runs.
