# Control Who Can Run Pipelines

A PipelineRun runs code from the pull request, in your cluster, often with access to Secrets: registry credentials, deploy tokens, signing keys. If anyone on the internet could open a pull request and have it run, anyone could read those Secrets with one changed line in a test script. Pipelines-as-Code therefore checks who sent each event before it creates any run. This part covers the rules, the `OWNERS` file, and the comments that let a trusted person approve a run.

## Who may run pipelines

For every pull request event, the pipelines-as-code-controller checks the sender of the event (the author of the pull request, or the author of a new commit). The sender may run pipelines when any of these is true:

- The sender is the owner of the repository.
- The sender is a collaborator with write access (on GitHub: push permission).
- The sender is a member of the organization that owns the repository.
- The sender is listed under `approvers` or `reviewers` in the `OWNERS` file on the default branch.

Anyone else gets no PipelineRun. Instead, the controller writes a commit status named `Pipelines as Code CI` in the state `pending`, with the description `Pending approval, waiting for an /ok-to-test`, and a comment that says the user is not allowed to trigger CI in this repository. On GitHub, bot accounts get no pending status unless they are allowed explicitly.

<!-- astrona:playground:renew -->

See it with the Gitea user `cadet`, who has no rights on `starfleet/bridge-app`. As `cadet`, fork the repository, change one file on a new branch of the fork, and open a pull request into `starfleet/bridge-app`:

```sh
cadet_api() {
  kubectl -n gitea exec deploy/tester -- curl -sS -u cadet:cadet-password \
    -X "$1" -H 'Content-Type: application/json' --data "$3" "http://gitea-http.gitea:3000/api/v1$2"
}
cadet_api POST /repos/starfleet/bridge-app/forks '{}'
cadet_api POST /repos/cadet/bridge-app/branches '{"new_branch_name":"docs-typo","old_branch_name":"main"}'
cadet_api POST /repos/cadet/bridge-app/contents/docs/typo.md \
  "{\"branch\":\"docs-typo\",\"message\":\"Fix a typo\",\"content\":\"$(printf 'Typo fixed.\n' | base64 | tr -d '\n')\"}"
cadet_api POST /repos/starfleet/bridge-app/pulls '{"head":"cadet:docs-typo","base":"main","title":"Fix a typo"}'
```

The last answer shows the new pull request and its `number`. No PipelineRun appears in `starfleet`. Read the pull request's statuses and comments as `starfleet`; replace `<NUMBER>` with the number Gitea returned:

```sh
kubectl -n gitea exec deploy/tester -- sh -c 'sha="$(curl -sS -u starfleet:starfleet-password http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/pulls/$1 | jq -r .head.sha)"; curl -sS -u starfleet:starfleet-password "http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/commits/$sha/statuses" | jq -r ".[] | \"\(.context): \(.status) - \(.description)\""' _ <NUMBER>
kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/issues/$1/comments | jq -r ".[].body"' _ <NUMBER>
```

The status is `Pipelines as Code CI: pending - Pending approval, waiting for an /ok-to-test`, and the comment says that `cadet` is not allowed to trigger CI.

## GitOps commands

A GitOps command is a pull request comment that Pipelines-as-Code acts on. The comment must start a line with the command. The webhook must send comment events (on Gitea: `pull_request_comment`).

| Command | What it does |
| --- | --- |
| `/ok-to-test` | An allowed user approves the pull request: Pipelines-as-Code runs the matching templates for the current commit |
| `/retest` | Runs again every template that failed for the current commit (or that never ran); succeeded runs are skipped |
| `/retest <name>` or `/test <name>` | Runs one template by name, even if it succeeded before |
| `/cancel` or `/cancel <name>` | Cancels the running PipelineRuns of the pull request, or one of them |

Pipelines-as-Code checks the comment's author with the same rules as above. A comment `/ok-to-test` from `cadet` does nothing. Approve the pull request as `starfleet`:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X POST -H 'Content-Type: application/json' \
  http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/issues/<NUMBER>/comments --data '{"body":"/ok-to-test"}'
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/sender,pipelinesascode.tekton.dev/event-type
```

`lint` and `unit-test` start for `cadet`'s commit. The templates clone `{{ source_url }}`, which for this pull request is the fork `cadet/bridge-app`, and check out `{{ revision }}`. An approval covers the current commit only. When `cadet` pushes another commit, the new commit waits for approval again, unless `remember-ok-to-test: "true"` is set in the ConfigMap `pipelines-as-code`. On GitHub, an administrator can also set `require-ok-to-test-sha: "true"`, so that reviewers must write the commit SHA after the command (`/ok-to-test 1a2b3c4`); other providers send the SHA with the comment event, so they do not need it.

## Trust a contributor with OWNERS

Approving every commit of a regular contributor gets tiring, and giving them write access to the repository gives far more than CI. The `OWNERS` file is the middle way. It is a YAML file at the top of the default branch, in the format of the Kubernetes project's `OWNERS` files:

```yaml
approvers:
  - starfleet
reviewers:
  - cadet
```

Both lists grant the same right in Pipelines-as-Code: the users in them may run pipelines. An `OWNERS_ALIASES` file next to it can define named groups of users. Pipelines-as-Code reads both files from the default branch only, so a pull request cannot add its own author. The `Repository` field `spec.settings.policy` gives finer control on providers with teams: `ok_to_test` and `pull_request` list the teams whose members may approve or run pull requests.

You now know the access rules of Pipelines-as-Code: owners, collaborators with write access, organization members and `OWNERS` entries may run pipelines; everyone else waits for `/ok-to-test` from one of them. With that, you can let outside contributors in without handing them the cluster's Secrets.

## Common pitfalls

> [!WARNING]
> - **Commenting `/ok-to-test` as the contributor.** Only an allowed user's comment counts.
> - **Putting `OWNERS` on the pull request's branch.** Pipelines-as-Code reads it from the default branch.
> - **Giving write access to trust CI.** Write access also lets the user push to the repository; an `OWNERS` entry only lets them run pipelines.
> - **Expecting `/retest` to rerun a successful run.** It reruns failed runs only; use `/test <name>` to force one.
> - **Expecting comment commands without comment events.** The webhook must send pull request comments.
