# Secrets And The Git Provider Token In A Run

Some values must not be written into a template or a `Repository`: a registry password, a deploy token, a key for a private package index. Pipelines-as-Code offers two ways to give a run a value from a Secret. The first is a parameter with `secret_ref`. The second is the Secret that the controller creates for the run, with a token to clone a private repository.

## A parameter from a Secret

A custom parameter can name a Secret instead of holding a value. Create the Secret in the namespace of the `Repository`:

```sh
kubectl -n starfleet create secret generic deploy-credentials --from-literal=token=starfleet-deploy-token
```

<!-- astrona:playground:renew -->

Save this as `repository-bridge-app.yaml`. It adds a parameter that reads the key `token` of the Secret:

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
  params:
    - name: deploy_token
      secret_ref:
        name: deploy-credentials
        key: token
```

Apply it:

```sh
kubectl apply -f repository-bridge-app.yaml
```

Then check the result:

```sh
kubectl -n starfleet get repository bridge-app -o jsonpath='{.spec.params[0].secret_ref}{"\n"}'
```

The command prints the Secret name and key and not the value. The template uses the parameter like any other:

```yaml
    - name: deploy_token
      value: "{{ deploy_token }}"
```

The controller reads the Secret when the event arrives and puts the value into the PipelineRun parameter. Read this carefully: that means the value is part of the PipelineRun object and can be read by anyone who can read PipelineRuns in the namespace. For a stronger protection, mount the Secret into the step in the Pipeline instead, and pass only its name through the parameter.

## Print the length, never the value

A step that needs to confirm a secret arrived can print its length, which does not reveal it. In the template:

```yaml
- name: check-token
  image: alpine:3.20
  env:
    - name: TOKEN
      value: "$(params.deploy_token)"
  script: |
    #!/bin/sh
    echo "token length: ${#TOKEN}"
```

The value goes through an environment variable so that it is not written into the script text. Do not use `set -x` in steps that handle secrets, because it echoes every command with its expanded values.

## The Git token for cloning

A private repository cannot be cloned without credentials. For each run, Pipelines-as-Code creates a Secret that holds the provider token and puts its name in the variable `{{ git_auth_secret }}`. The Secret has the key `git-provider-token`. Pass it to a clone step as a workspace:

```yaml
workspaces:
  - name: basic-auth
    secret:
      secretName: "{{ git_auth_secret }}"
```

The Secret is removed when the run is cleaned up. The ConfigMap key `secret-auto-create` controls whether it is created. If a cluster turns it off, `{{ git_auth_secret }}` does not exist and the clone of a private repository fails. The repository of the playground is public, so its templates need no token.

## Which one to use

| Need | Use |
| --- | --- |
| A fixed, non-secret value that changes per repository | A `params` entry with `value` |
| A value that depends on the event or branch | A `params` entry with `filter` |
| A secret value for a step | A `secret_ref` parameter, or a Secret mounted by the Pipeline |
| A token to clone a private repository | `{{ git_auth_secret }}` as a workspace |

## Common pitfalls

> [!WARNING]
> - **A Secret in another namespace.** The Secret must be in the namespace of the `Repository`.
> - **Printing a secret to the log.** A step log is readable by everyone who can read the pod logs. Print a length or a hash prefix.
> - **Using `set -x` in a step with a secret.** It prints the expanded values.
> - **Expecting the PipelineRun to hide the value.** A parameter from `secret_ref` is stored in the run.
