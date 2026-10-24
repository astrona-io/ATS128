# Overview: Connect A Git Repository To Pipelines-as-Code (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Tekton Pipelines and a Git server, and leaves the installation of Pipelines-as-Code to you. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Tekton Pipelines v1.17.1** in the namespaces `tekton-pipelines` and `tekton-pipelines-resolvers`.
- **Gitea 28.2.0**, a Git server, in the namespace `gitea`. Its Service `gitea-http` listens on port 3000 inside the cluster (`http://gitea-http.gitea.svc.cluster.local:3000`). It may send webhooks to Services in the cluster.
- The Gitea user `starfleet` (password `starfleet-password`, lab-only credentials) and its access token in the Secret `gitea-token` (key `token`) in the namespace `gitea`.
- The public repository `starfleet/bridge-app`: `app/VERSION`, `app/status.sh`, `docs/guide.md` and `.tekton/pull-request.yaml` on `main`, and the branch `feature-hello`, which changes `app/VERSION` to `1.5.0`.
- A `tester` pod in the namespace `gitea` with `curl` and `jq`, for calls to the Gitea API.
- An empty namespace `starfleet` for the `Repository` and the PipelineRuns.
- `tkn` 0.46.2 and the Pipelines-as-Code plugin `tkn pac` (program `tkn-pac`) 0.52.0 on your PATH.
- **Not installed:** Pipelines-as-Code. Install it with `kubectl apply -f https://github.com/tektoncd/pipelines-as-code/releases/download/v0.52.0/release.k8s.yaml`.

## Helpers

Paste these once in each new terminal. `gitea_get` sends a GET request to the Gitea API from the `tester` pod and filters the answer with `jq`. `gitea_send` sends a request with a JSON body. `show_runs` lists the PipelineRuns in `starfleet` with their event type and commit.

```sh
gitea_get() {
  kubectl -n gitea exec deploy/tester -- sh -c \
    'curl -sS -u starfleet:starfleet-password "http://gitea-http.gitea.svc.cluster.local:3000/api/v1$1" | jq -r "$2"' _ "$1" "${2:-.}"
}
gitea_send() {
  kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
    -X "$1" -H 'Content-Type: application/json' --data "$3" "http://gitea-http.gitea.svc.cluster.local:3000/api/v1$2"
}
show_runs() {
  kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/event-type,pipelinesascode.tekton.dev/sha
}
```

Use them like this: `gitea_get /repos/starfleet/bridge-app/pulls '.[].title'`, `gitea_send POST /repos/starfleet/bridge-app/pulls '{"head":"feature-hello","base":"main","title":"Test"}'`, `show_runs`.

To look at Gitea in a browser, run `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal and open `http://localhost:3000`. Sign in as `starfleet`. Links inside Gitea use the in-cluster host name; change the host to `localhost:3000` by hand.

## Practice tasks

- Install Pipelines-as-Code and list everything in the namespace `pipelines-as-code` with `kubectl get all -n pipelines-as-code`. Which pod receives webhooks, and on which port of which Service?
- Read the whole ConfigMap `pipelines-as-code` and find the settings for the application name, remote tasks and cleanup.
- Connect `starfleet/bridge-app`, open a pull request from `feature-hello`, and follow the run with `show_runs`, `tkn pac describe bridge-app -n starfleet` and `tkn pac logs bridge-app -n starfleet -L`.
- Try to create a second `Repository` with the same URL in the namespace `default`. Read the error of the admission webhook.
- Change the webhook secret in the Secret `gitea-webhook-config` only, push a commit to `feature-hello`, and find the error in the controller log. Put the secret back.
- Delete the webhook, recreate it on port 8082, close and reopen the pull request, and see that nothing runs. Recreate it on port 8080.
