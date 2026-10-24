# Install Pipelines-as-Code And The tkn pac Plugin

Pipelines-as-Code runs on top of Tekton Pipelines, so a cluster needs both. Tekton Pipelines is already running in your playground; Pipelines-as-Code is not. Installing it is one `kubectl apply`, but you should know what that command creates: the Deployments you will read logs from, the Service the Git provider must reach, and the ConfigMap that holds the settings.

## Apply the release manifest

Each Pipelines-as-Code release publishes two manifests. `release.k8s.yaml` is for plain Kubernetes, such as your `kind` cluster; `release.yaml` is for OpenShift. The course pins version v0.52.0, so install the file of that release.

<!-- astrona:playground:renew -->

Apply the manifest and wait until the three Deployments are ready:

```sh
kubectl apply -f https://github.com/tektoncd/pipelines-as-code/releases/download/v0.52.0/release.k8s.yaml
kubectl -n pipelines-as-code rollout status deployment/pipelines-as-code-controller
kubectl -n pipelines-as-code rollout status deployment/pipelines-as-code-watcher
kubectl -n pipelines-as-code rollout status deployment/pipelines-as-code-webhook
```

Each `rollout status` command ends with a line that says the Deployment was successfully rolled out. The first start pulls three images from `ghcr.io`, so it can take a minute.

Then check the version that the installation reports:

```sh
kubectl get deployments -n pipelines-as-code
kubectl -n pipelines-as-code get configmap pipelines-as-code-info -o jsonpath='{.data.version}{"\n"}'
```

The first command lists `pipelines-as-code-controller`, `pipelines-as-code-watcher` and `pipelines-as-code-webhook`, each with `1/1` ready. The second prints `v0.52.0`. The ConfigMap `pipelines-as-code-info` is readable by every authenticated user, so anyone can find out which version runs.

## What the manifest created

The manifest created the namespace `pipelines-as-code` and everything inside it. Three objects matter for daily work, and one of them is easy to get wrong.

The **Service** `pipelines-as-code-controller` is where webhooks arrive. Look at its ports:

```sh
kubectl -n pipelines-as-code get service pipelines-as-code-controller -o jsonpath='{range .spec.ports[*]}{.name} {.port} -> {.targetPort}{"\n"}{end}'
```

It prints `http-listener 8080 -> 8082` and `http-metrics 9090 -> 9090`. The controller container listens on port 8082, but the Service publishes it on port **8080**. A webhook must target the Service port: `http://pipelines-as-code-controller.pipelines-as-code.svc.cluster.local:8080` from inside the cluster. On a real cluster, an Ingress or an OpenShift Route publishes the same Service to the Git provider on the internet.

The **custom resource definition (CRD)** `repositories.pipelinesascode.tekton.dev` adds the `Repository` kind. Its short name is `repo`:

```sh
kubectl api-resources --api-group=pipelinesascode.tekton.dev
```

The output shows one resource, `repositories`, with the short name `repo`, the API version `pipelinesascode.tekton.dev/v1alpha1`, and `NAMESPACED` set to `true`.

The **ConfigMap** `pipelines-as-code` holds the settings of the whole installation. Read two of them:

```sh
kubectl -n pipelines-as-code get configmap pipelines-as-code -o jsonpath='{.data.application-name}{"\n"}{.data.remote-tasks}{"\n"}'
```

It prints `Pipelines as Code CI` and `true`. The application name is the prefix of every status that Pipelines-as-Code writes to a pull request, so a run of the PipelineRun `pull-request` shows up as `Pipelines as Code CI / pull-request`. `remote-tasks: "true"` lets PipelineRuns fetch Tasks from outside the repository. The same ConfigMap also holds the defaults for cancelling runs, cleaning up old runs and remembering `/ok-to-test`; each of them is explained where it is used.

## The tkn pac plugin

`tkn pac` is the Pipelines-as-Code command-line tool. It is a separate program, `tkn-pac`, and `tkn` runs every program named `tkn-<name>` on your PATH as a plugin, so `tkn pac` and `tkn-pac` are the same command. Your playground installed version 0.52.0. Check it and ask it about the installation:

```sh
tkn pac version
tkn pac info install
```

`tkn pac version` prints the client version. `tkn pac info install` reads the cluster and reports the version of the controller and the namespace it runs in. With a GitHub App it would also show the App's details; your installation has none.

The plugin has more commands that you will use later: `tkn pac list` and `tkn pac describe` show the `Repository` objects and their recent runs, `tkn pac logs` prints the logs of a run, `tkn pac resolve` turns a `.tekton` file into a plain PipelineRun on your machine, and `tkn pac bootstrap` creates a GitHub App and its Secret on a cluster that uses GitHub. `tkn pac create repository` asks a few questions, creates the `Repository` and its Secret, and adds the webhook on the provider for you.

You now have a working installation: a controller behind a Service on port 8080, a watcher, an admission webhook, the `Repository` CRD and the settings ConfigMap. Nothing runs yet, because no repository is connected.

## Common pitfalls

> [!WARNING]
> - **Applying `release.yaml` on plain Kubernetes.** That file is for OpenShift. Use `release.k8s.yaml`.
> - **Installing from a moving URL.** A link to the `stable` branch changes with every release. Pin the release asset of the version you test.
> - **Pointing a webhook at port 8082.** That is the container port. The Service listens on 8080.
> - **Creating a `Repository` before the admission webhook answers.** Right after the installation, the API server can refuse the object with a webhook error. Wait a few seconds and apply it again.
