# Summary

Pipelines-as-Code turns Git events into Tekton PipelineRuns. The pipeline lives in the repository's `.tekton` folder as a template, so it is versioned and reviewed with the code, and the result comes back to the pull request.

## What you learned

Three components do the work. The pipelines-as-code-controller receives the provider's webhook, checks its signature, finds the `Repository` for the event's URL, reads `.tekton` through the provider's API, and creates the matching PipelineRuns with generated names. The pipelines-as-code-watcher follows those runs and reports the final status back to the provider. The pipelines-as-code-webhook is an admission webhook that validates `Repository` objects and allows only one per repository URL in the whole cluster.

On GitHub, a GitHub App is the recommended connection: one App per cluster, short-lived tokens for each event, results in the Checks tab and GitOps comments. A plain GitHub webhook needs a personal access token per repository and reports in a pull request comment. GitLab, Bitbucket, Forgejo and Gitea also use a token and a webhook per repository; Gitea shows the result as a commit status and a comment. The labs use an in-cluster Gitea because a laptop cannot host a GitHub App or receive webhooks from the internet.

The installation is one manifest per release: `release.k8s.yaml` for Kubernetes. It creates the namespace `pipelines-as-code`, the three Deployments, the Service `pipelines-as-code-controller` on port 8080 (container port 8082), the `Repository` CRD (short name `repo`) and the ConfigMaps `pipelines-as-code` (settings, such as the application name `Pipelines as Code CI`) and `pipelines-as-code-info` (the version). The `tkn pac` plugin checks the installation and shows repositories, runs and logs.

A connection needs a Secret with `provider.token` and `webhook.secret`, a `Repository` in the namespace where the runs belong, and a webhook of the provider's type that targets the controller Service. The key facts to remember are these:

- The `Repository` URL must match the URL in the provider's events exactly.
- The Secret lives in the same namespace as the `Repository`.
- The webhook secret must be the same in the Secret and on the provider.
- A missing run shows up in the controller log and the namespace events, not in the provider's delivery list.

<!-- astrona:playground:destroy -->
