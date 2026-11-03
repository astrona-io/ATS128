# Local And Remote Tasks And Pipelines

A PipelineRun in `.tekton` can contain all its steps, or it can point to a Pipeline and Tasks defined elsewhere. Pipelines-as-Code gathers the definitions and puts them into the PipelineRun before it is created, so Tekton receives one self-contained object. This part shows the places a definition can come from and the settings that allow them.

## Tasks in the same folder

Any `Task` or `Pipeline` file in `.tekton` (and its subfolders) can be referenced by name. Pipelines-as-Code finds the object with that name in the folder and embeds it. Save this as `.tekton/tasks/print-status.yaml` in your repository:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: print-status
spec:
  params:
    - name: revision
      type: string
  steps:
    - name: print
      image: alpine:3.20
      script: |
        #!/bin/sh
        echo "checking commit $(params.revision)"
```

<!-- astrona:playground:renew -->

A template then uses it with `taskRef`:

```yaml
pipelineSpec:
  tasks:
    - name: status
      taskRef:
        name: print-status
      params:
        - name: revision
          value: "{{ revision }}"
```

Put both files on a branch of `bridge-app` and open a pull request. The run resolves the reference from the folder at the commit of the event. Change the name in `taskRef` to one that does not exist and push again: the controller cannot resolve the reference and reports an error on the pull request instead of creating a run.

## Tasks and pipelines from outside

For definitions that live outside the repository, annotations name the source. Pipelines-as-Code fetches it and embeds it:

| Annotation | Value | Source |
| --- | --- | --- |
| `pipelinesascode.tekton.dev/task` | `git-clone` | A catalog entry, by name |
| `pipelinesascode.tekton.dev/task` | `https://example.invalid/task.yaml` | A raw file at a URL |
| `pipelinesascode.tekton.dev/task` | `./.tekton/tasks/print-status.yaml` | A file in the same repository |
| `pipelinesascode.tekton.dev/pipeline` | A URL or a path | A whole Pipeline |

The task annotation takes a list, written as `"[git-clone, ./.tekton/tasks/print-status.yaml]"`, so one template can use several sources. A reference by name in the template, such as `taskRef: {name: git-clone}`, is then matched with the fetched Task of that name.

The address in the table is a placeholder. Use the address of a file you control, and pin it to a tag or a commit so it cannot change without a review. A URL that points at a moving branch makes your pipeline change when someone else pushes.

## Settings that allow remote definitions

The ConfigMap key `remote-tasks` turns the fetching of remote definitions on or off for the whole installation. When it is off, a template with a remote `task` annotation does not resolve. The `hub-url` key sets the catalog that short names such as `git-clone` are read from. Read both:

```sh
kubectl -n pipelines-as-code get configmap pipelines-as-code -o jsonpath='{.data.remote-tasks}{" "}{.data.hub-url}{"\n"}'
```

A cluster without access to the internet cannot reach a public catalog. In that case, keep the Tasks in the repository, or host them on a server that the cluster can reach. The playground has no guaranteed internet access, so its templates use local Tasks and plain images.

## When to use which

- Local files are best for steps that belong to one repository. They are reviewed with the code and need no network.
- A URL fits a shared Task that a platform team publishes, if it is pinned.
- A catalog name is convenient, but it ties your pipeline to an outside source and a version you must check.

## What the controller does with a Task it cannot find

If a referenced Task is not found, the controller does not create the PipelineRun. It reports the failure on the pull request or the commit, with the name it could not resolve. Read the cluster side of the same failure in the controller log:

```sh
kubectl -n pipelines-as-code logs deploy/pipelines-as-code-controller --tail=30
```

## Common pitfalls

> [!WARNING]
> - **A Task file that is not in `.tekton`.** Only files in that folder are found by name.
> - **A URL that points at a branch.** The Task changes when the branch changes. Pin it to a tag or commit.
> - **Remote Tasks in a cluster without internet.** The fetch fails and no run is created.
> - **Two Tasks with the same name in the folder.** Which one a reference gets is unclear. Keep names unique.
