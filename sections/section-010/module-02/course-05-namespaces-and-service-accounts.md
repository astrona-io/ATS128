# Namespaces, ServiceAccounts And Quotas For A Repository

The namespace of a `Repository` is where its runs execute, so it is also where you limit what they may do. A pipeline that builds a pull request from a stranger should not have the rights of a pipeline that deploys to production. This part shows how to give a repository its own ServiceAccount, how a template selects it, and how a quota limits the load.

## One namespace for each repository or team

Pipelines-as-Code creates PipelineRuns in the namespace of the `Repository`. Everything those runs can use is in that namespace: Secrets, ConfigMaps, ServiceAccounts and PersistentVolumeClaims. Putting teams in separate namespaces keeps their Secrets apart. Read the objects of the playground namespace:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet get serviceaccounts,secrets,resourcequotas
```

The namespace has the `default` ServiceAccount and the connection Secret. The connection Secret holds the provider token, so any pod that can mount it can read the token. Keep deploy credentials out of a namespace that runs untrusted pull requests.

## A ServiceAccount for the runs

A PipelineRun runs its pods as a ServiceAccount. The template names it in `spec.taskRunTemplate.serviceAccountName`. Save this as `serviceaccount-ci.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci-runner
  namespace: starfleet
```

Apply it:

```sh
kubectl apply -f serviceaccount-ci.yaml
```

Then check the result:

```sh
kubectl -n starfleet get serviceaccount ci-runner
```

Add the name to a template:

```yaml
spec:
  taskRunTemplate:
    serviceAccountName: ci-runner
```

The new ServiceAccount has no rights, which is the right start. Grant only what the pipeline needs, with a Role and a RoleBinding in the same namespace.

## Limit the load with a quota

A ResourceQuota caps the total resources of the namespace, so a flood of pull requests cannot take the cluster. Save this as `resourcequota-ci.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ci-quota
  namespace: starfleet
spec:
  hard:
    pods: "20"
```

Apply it:

```sh
kubectl apply -f resourcequota-ci.yaml
```

Then check the result:

```sh
kubectl -n starfleet describe resourcequota ci-quota
```

When the quota is reached, new pods are refused and runs wait or fail. `concurrency_limit` on the `Repository` is a gentler limit, because it queues whole runs before they create pods. Use both: the limit for order and the quota as a safety net.

## Who may create the Repository

The admission webhook of Pipelines-as-Code checks that the user who creates a `Repository` can create PipelineRuns in that namespace. A user without that right cannot connect a repository to a namespace they do not control. This keeps one team from sending runs into another team's namespace.

## Common pitfalls

> [!WARNING]
> - **Running untrusted pull requests in a namespace with deploy Secrets.** Any template can mount them.
> - **Granting `cluster-admin` to the ServiceAccount.** Give a Role in the namespace.
> - **A quota with too few pods.** Tasks with several steps use one pod each, so runs stall.
> - **Expecting the quota to queue runs.** It refuses pods. Use `concurrency_limit` to queue.
