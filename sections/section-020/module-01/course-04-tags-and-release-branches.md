# Tags And Release Branches

Teams build different things for different refs. A push to `main` builds an image, a push to `release-1.0` builds a patch release, and a tag such as `v1.2.0` publishes. Pipelines-as-Code matches these with branch globs on full reference names. This part shows the patterns that work and the mistakes that make a release pipeline silent.

## Full references, not short names

The annotation `on-target-branch` is matched against the full reference of the event. A branch is `refs/heads/<name>` and a tag is `refs/tags/<name>`. For convenience, a plain `main` matches `refs/heads/main`. A tag needs the full form:

| Goal | `on-target-branch` |
| --- | --- |
| Only `main` | `[main]` |
| `main` and every release branch | `[main, release-*]` |
| Every tag that starts with `v` | `[refs/tags/v*]` |
| A branch and the tags | `[main, refs/tags/v*]` |

<!-- astrona:playground:renew -->

## Match release branches

Save this as `.tekton/release-push.yaml` on `main`. It runs for pushes to `main` and to branches that start with `release-`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: release-push
  annotations:
    pipelinesascode.tekton.dev/on-event: "[push]"
    pipelinesascode.tekton.dev/on-target-branch: "[main, release-*]"
    pipelinesascode.tekton.dev/max-keep-runs: "3"
spec:
  pipelineSpec:
    tasks:
      - name: show-ref
        taskSpec:
          steps:
            - name: show
              image: busybox:1.37.0
              script: |
                #!/bin/sh
                echo "target branch: {{ target_branch }}"
                echo "revision: {{ revision }}"
```

Commit it to `main`, then create the branch `release-1.0` from `main` in Gitea. Pipelines-as-Code reads `.tekton` from the pushed commit, so the file must exist on that branch, and a branch created from `main` has it. List the runs:

```sh
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/original-prname
```

A run of `release-push` exists for the push to `main`. Push a commit to `release-1.0` and a second run appears. Push to a branch named `feature-hello` and no new run appears, because the glob does not match.

## Match tags

A tag push has the reference `refs/tags/v1.2.0`. A template for it needs the full form. Change the annotation to this value:

```yaml
    pipelinesascode.tekton.dev/on-target-branch: "[refs/tags/v*]"
```

A tag created in Gitea sends a push event with the tag reference. The branch name `v1.2.0` does not match, and `main` does not match either, so this template runs only for tags.

## Use the CEL form for complex rules

When a rule needs more than one condition, a CEL expression is clearer than several annotations. This one runs for a push to `main` or to a release branch:

```yaml
    pipelinesascode.tekton.dev/on-cel-expression: |
      event == "push" && (target_branch == "main" || target_branch.matches("^release-"))
```

Remember that a CEL expression overrides `on-event` and `on-target-branch`, so remove them or keep them in agreement to avoid confusion.

## Common pitfalls

> [!WARNING]
> - **A tag pattern without `refs/tags/`.** The template never matches a tag.
> - **A release branch without the template.** Pipelines-as-Code reads the files of the pushed commit, so the branch needs the `.tekton` file itself.
> - **A glob with a slash in a name.** Branch names with slashes make API paths and globs harder. Keep names simple.
> - **Mixing CEL and annotations.** The expression wins, and the annotations hide the real rule.
