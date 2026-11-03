# Share One Pipeline Between Repositories

Ten repositories of one team often need the same pipeline: clone, test, build. Copying the same YAML ten times means ten places to fix. Pipelines-as-Code lets a template reference a shared Pipeline from a URL and supply the repository-specific values from the `Repository`. This part shows the pattern and its limits.

## The shape of a thin template

A thin template holds only the matching and the parameters. The Pipeline, with the steps, lives in one shared file. The template points at it with the `pipeline` annotation and uses `pipelineRef`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: pull-request
  annotations:
    pipelinesascode.tekton.dev/on-event: "[pull_request]"
    pipelinesascode.tekton.dev/on-target-branch: "[main]"
    pipelinesascode.tekton.dev/pipeline: "./.tekton/shared/build-test.yaml"
spec:
  pipelineRef:
    name: build-test
  params:
    - name: repo_url
      value: "{{ repo_url }}"
    - name: revision
      value: "{{ revision }}"
    - name: deploy_target
      value: "{{ deploy_target }}"
```

<!-- astrona:playground:renew -->

In the example the path is in the same repository. For a pipeline shared by many repositories, the value is a URL to a file in a repository that the platform team owns. Pin it to a tag, so every change is a reviewed release.

## Put the shared Pipeline in place

Save this as `.tekton/shared/build-test.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: build-test
spec:
  params:
    - name: repo_url
      type: string
    - name: revision
      type: string
    - name: deploy_target
      type: string
  tasks:
    - name: show
      params:
        - name: revision
          value: $(params.revision)
        - name: deploy_target
          value: $(params.deploy_target)
      taskSpec:
        params:
          - name: revision
            type: string
          - name: deploy_target
            type: string
        steps:
          - name: show
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "testing $(params.revision) for $(params.deploy_target)"
```

Commit both files to a branch of `bridge-app` and open a pull request. The run uses the Pipeline from the folder, and the parameter `deploy_target` comes from the `Repository`, so another repository can use the same files with its own value. Check the result:

```sh
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/original-prname
```

## What stays in each repository

| Item | Where it lives |
| --- | --- |
| Which events and branches run | The thin template in each repository |
| Environment values and Secrets | The `Repository` of each repository |
| The steps | The shared Pipeline |

This split lets a platform team improve the steps once and lets each team keep control of when its pipeline runs.

## Risks of sharing

A shared Pipeline is a dependency. A change to it affects every repository that uses it at the next run. Review changes like code, pin consumers to tags, and keep a changelog. If the address becomes unreachable, remote fetching fails and the runs of every consumer fail with it.

## Common pitfalls

> [!WARNING]
> - **Using a branch address for the shared Pipeline.** Everyone gets each commit at once.
> - **Writing environment values in the shared file.** Pass them as parameters.
> - **Different parameter names in the template and the Pipeline.** A missing parameter makes the run fail at creation.
> - **Sharing across a cluster without internet access.** Host the file inside the network.
