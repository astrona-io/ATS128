# Custom Parameters On The Repository

Pipelines-as-Code fills the dynamic variables of an event into a template before it creates the PipelineRun. The same mechanism supplies values that you define yourself. A custom parameter is a name and a value in the `Repository`, and a template reads it as `{{ name }}`. This keeps environment-specific values out of the template, so the template can be copied between repositories unchanged.

## The built-in dynamic variables

These variables are always available. The values come from the event:

| Variable | Value |
| --- | --- |
| `{{ revision }}` | The commit SHA of the event |
| `{{ repo_url }}` | The URL of the repository |
| `{{ repo_owner }}` and `{{ repo_name }}` | The owner and the name of the repository |
| `{{ source_url }}` | The clone URL of the source of the change. For a pull request from a fork, it is the fork |
| `{{ source_branch }}` and `{{ target_branch }}` | The branch with the change and the branch it merges into |
| `{{ event_type }}` | The event, such as `pull_request` or `push` |
| `{{ sender }}` | The user who caused the event |
| `{{ pull_request_number }}` | The number of the pull request, for pull request events |
| `{{ target_namespace }}` | The namespace where the run is created |
| `{{ trigger_comment }}` | The comment that caused the run, for comment events |
| `{{ git_auth_secret }}` | The name of the Secret with a token for cloning |

<!-- astrona:playground:renew -->

Some of these have no value for some events. A variable that Pipelines-as-Code does not know is left as the literal text `{{ name }}` in the PipelineRun. That is how a mistyped variable shows up: the run starts, and a parameter holds the braces.

## Define a custom parameter

A custom parameter belongs to the `Repository`. Save this as `repository-bridge-app.yaml`:

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
    - name: deploy_target
      value: shuttle-bay
    - name: log_level
      value: debug
```

Apply it:

```sh
kubectl apply -f repository-bridge-app.yaml
```

Then check the result:

```sh
kubectl -n starfleet get repository bridge-app -o jsonpath='{range .spec.params[*]}{.name}={.value}{"\n"}{end}'
```

The command prints `deploy_target=shuttle-bay` and `log_level=debug`. The values are substituted into the template when the next event arrives. A PipelineRun that already exists keeps what it got.

Use the parameter in a template by writing it in a PipelineRun parameter. The `.tekton/push.yaml` of the playground can pass it to its Pipeline like this:

```yaml
spec:
  params:
    - name: deploy_target
      value: "{{ deploy_target }}"
```

Pipelines-as-Code replaces `{{ deploy_target }}` with `shuttle-bay` before the PipelineRun exists. Read it afterwards from the run:

```sh
kubectl get pipelinerun -n starfleet -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.params}{"\n"}{end}'
```

## Limit a parameter with a filter

A parameter can carry a `filter`, a CEL expression that must be true for the parameter to get its value. The expression sees the event through the `pac` object, for example `pac.event_type` and `pac.target_branch`. This gives one name different values for different events:

```yaml
  params:
    - name: deploy_target
      value: shuttle-bay
      filter: pac.event_type == "push" && pac.target_branch == "main"
    - name: deploy_target
      value: test-bay
      filter: pac.event_type == "pull_request"
```

Keep the filters of parameters with the same name from overlapping, because it is hard to see which value a given event gets. When no parameter matches, the variable has no value and stays as literal text, so a template that depends on it should check for that, as the lab does.

## Choose names that cannot clash

The built-in variables and your own live in the same namespace of names. A custom parameter named like a built-in variable, such as `revision`, makes it unclear which value a template gets. Use a prefix for your own names in a shared template, such as `app_` or the name of the team.

## Your mission: Define Custom Parameters On The Repository

You can now define custom parameters and say how a template reads them. The graded lab gives you a pull request whose pipeline fails, because the template uses two variables that no one defined. You define them on the `Repository` and start the pipeline again.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-128-playground-020-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS128.git -c sections/section-020/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-128-lab-020-02
astrona start ats-128-playground-020-02
```

## Common pitfalls

> [!WARNING]
> - **A mistyped variable name.** The run starts with the literal text `{{ name }}` in the parameter instead of a value.
> - **Two parameters with the same name and overlapping filters.** It is hard to see which value an event gets. Keep the filters apart.
> - **Putting a secret value in `value`.** The `Repository` is readable by everyone who can read it in the namespace, and the value is copied into every PipelineRun. Use `secret_ref`.
> - **Expecting an old run to change.** Values are fixed when the PipelineRun is created.
