# Choose Where Pipeline Definitions Come From

A pull request can change any file of a repository, and the files in `.tekton` are among them. By default, Pipelines-as-Code reads the pipeline definitions from the commit of the event. That is useful: a developer can test a new pipeline in the pull request that introduces it. It is also a risk: the same developer can change what the pipeline does in the pull request that is being tested. This part shows how the choice works, what it means for trust, and which settings narrow it.

## Two sources for the definitions

The setting is `settings.pipelinerun_provenance` in the `Repository`. It has two values:

| Value | Where the `.tekton` files are read from |
| --- | --- |
| `source` | The commit of the event. This is the default. A pull request runs its own version of the pipelines |
| `default_branch` | The default branch of the repository. A pull request runs the pipelines of the branch it merges into |

The default branch is the branch the Git server marks as the default. The names of the templates are the same in both cases. What changes is which file content is used.

<!-- astrona:playground:renew -->

Read the current value in the playground. A missing field means the default, `source`:

```sh
kubectl -n starfleet get repository bridge-app -o jsonpath='{.spec.settings}{"\n"}'
```

## What a pull request can do with the source setting

The pipeline runs with the Secrets and the ServiceAccount of the namespace. A template that comes from the pull request decides which steps run in that context. A step can read every Secret that the ServiceAccount can mount, call external services and report a success that was never earned. Anyone who can open a pull request in a repository that is not trusted can therefore influence what runs in your cluster.

Pipelines-as-Code adds a gate for this: a pull request from a user who is not an owner or collaborator, and who is not allowed by the repository policy, does not start a run until an allowed user comments `/ok-to-test`. The gate stops strangers. It does not stop a collaborator from changing a template in their own pull request, and that is the case the next setting addresses.

## What default_branch changes

With `default_branch`, the controller reads `.tekton` from the default branch and still takes the event values from the pull request. The changed file in the pull request is not used. The pull request is tested by the reviewed pipeline, and a change to the pipeline itself takes effect only after the merge.

This comes with a trade-off. A developer who works on a new pipeline cannot see it run in the pull request. They must merge first, or use a branch in a repository where `source` is set. Teams that use `default_branch` usually keep the pipelines in a repository with strict review, and keep the application repositories on this setting.

Save this as `repository-bridge-app.yaml`. It is the playground `Repository` with the setting added:

```yaml
apiVersion: pipelinesascode.tekton.dev/v1alpha1
kind: Repository
metadata:
  name: bridge-app
  namespace: starfleet
spec:
  url: "http://gitea-http.gitea.svc.cluster.local:3000/starfleet/bridge-app"
  settings:
    pipelinerun_provenance: default_branch
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
kubectl -n starfleet get repository bridge-app -o jsonpath='{.spec.settings.pipelinerun_provenance}{"\n"}'
```

The command prints `default_branch`. Open a pull request that changes a file in `.tekton` and read which version ran. The run takes its steps from the default branch, so the steps of the pull request are not used.

## Who may start a run

The same `settings` block has a `policy` field that lists the users and teams allowed to start runs from a pull request. It has two lists, `ok_to_test` and `pull_request`. A member of `ok_to_test` can approve a stranger's pull request with `/ok-to-test`. A member of `pull_request` may open a pull request that starts runs without approval. The field depends on the provider: GitHub uses team names, and other providers have narrower support, so read the reference of your release before you rely on it.

## Other protections that go with the choice

- Keep the ServiceAccount of the namespace small. A pipeline that does not need to push to a registry should not run with a ServiceAccount that can.
- Keep deploy Secrets in a namespace that runs only trusted pipelines.
- Use `concurrency_limit` to limit the load that an open pull request can create.

None of these replaces the choice of `default_branch` for a repository that takes pull requests from many people.

## Your mission: Run Pull Requests With The Pipeline From The Default Branch

You can now say where Pipelines-as-Code reads its definitions from and what a pull request can change. The graded lab connects a repository whose open pull request contains a tampered pipeline. The pipeline in the pull request skips the test and fails on purpose, and the pipeline on the default branch is correct. You change the `Repository` so that the pull request is tested with the correct pipeline.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-128-playground-010-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS128.git -c sections/section-010/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-128-lab-010-02
astrona start ats-128-playground-010-02
```

## Common pitfalls

> [!WARNING]
> - **Setting `default_branch` and expecting a new pipeline to run in its own pull request.** The new file is not on the default branch yet.
> - **Treating `/ok-to-test` as a review.** It lets the run start. It does not check what the template does.
> - **Relying on `source` for a public repository.** Anyone who can open a pull request can change what runs.
> - **Forgetting that a push to the default branch always uses its own commit.** Both values read the same files for pushes to that branch.
