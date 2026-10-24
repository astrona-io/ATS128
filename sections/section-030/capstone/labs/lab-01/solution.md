# Solution: Gate An Outside Contributor's Pull Request

Work the task yourself first. Running `astrona submit -c sections/section-030/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: pull request #1 was approved by `starfleet` with `/ok-to-test` and its head commit has a successful run and a `success` status; `OWNERS` on `main` lists `cadet`, who is not a collaborator; and a new commit from `cadet`, pushed by the grader, runs without approval.

## Step 1: Find why events are ignored

Gitea's delivery list shows HTTP 202 for every webhook, because the controller accepts the request before it checks it. Read the controller instead:

```sh
kubectl -n pipelines-as-code logs deploy/pipelines-as-code-controller --since=30m | grep -i signature
kubectl get events -n starfleet
```

The controller reports that the Gitea webhook signature validation failed. Gitea signs each webhook with the secret stored in the webhook, and the controller checks it with `webhook.secret` from the Secret `gitea-webhook-config`. The two differ, so the controller drops every event, before any access check: that is why `cadet` did not even get a pending status.

## Step 2: Use one webhook secret on both sides

Gitea never shows a webhook's secret, and it cannot change the secret of an existing webhook. So choose a new secret, write it into the Secret, and recreate the webhook with it:

```sh
NEW_SECRET="$(head -c 24 /dev/urandom | base64 | tr -d '/+=' | head -c 32)"
kubectl -n starfleet patch secret gitea-webhook-config --type merge -p "{\"stringData\":{\"webhook.secret\":\"$NEW_SECRET\"}}"
kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/hooks | jq -r ".[] | \"\(.id) \(.config.url)\""'
```

Delete the webhook with the `id` from the list, and create it again with the new secret:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X DELETE \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/hooks/<ID>
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  -X POST -H 'Content-Type: application/json' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/hooks \
  --data "{\"type\":\"gitea\",\"active\":true,\"branch_filter\":\"*\",\"events\":[\"push\",\"pull_request\",\"pull_request_sync\",\"pull_request_comment\"],\"config\":{\"url\":\"http://pipelines-as-code-controller.pipelines-as-code.svc.cluster.local:8080\",\"content_type\":\"json\",\"secret\":\"$NEW_SECRET\"}}"
```

The controller reads the Secret for every event, so no restart is needed.

## Step 3: Approve the pull request

The old pull request event was dropped, but a comment is a new event. Comment `/ok-to-test` as `starfleet`; `starfleet` owns the repository, so Pipelines-as-Code accepts the approval:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X POST -H 'Content-Type: application/json' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/issues/1/comments --data '{"body":"/ok-to-test"}'
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/sender,pipelinesascode.tekton.dev/event-type
```

A `pull-request-...` run starts. It clones `{{ source_url }}`, the fork `cadet/bridge-app`, at `cadet`'s commit. When it has finished, read the status:

```sh
SHA="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/pulls/1 | jq -r .head.sha')"
kubectl -n gitea exec deploy/tester -- sh -c "curl -sS -u starfleet:starfleet-password http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/commits/$SHA/statuses | jq -r '.[] | \"\(.context): \(.status) - \(.description)\"'"
```

The newest line for `Pipelines as Code CI / pull-request` is `success`.

## Step 4: Trust cadet with OWNERS

Save this as `OWNERS`:

```yaml
approvers:
  - starfleet
reviewers:
  - cadet
```

Commit it to the top of `main` (a new file, so POST works):

```sh
CONTENT="$(base64 < OWNERS | tr -d '\n')"
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X POST -H 'Content-Type: application/json' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/contents/OWNERS \
  --data "{\"branch\":\"main\",\"message\":\"Trust cadet as a reviewer\",\"content\":\"$CONTENT\"}"
```

Pipelines-as-Code reads `OWNERS` from the default branch for each event, so the next commit from `cadet` runs without approval. To see it yourself, commit a file as `cadet` to `docs-typo` in the fork and watch a new run start.

## Step 5: Submit

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Make `cadet` a collaborator with write access | Runs start, but `cadet` can also push to the repository; the grader rejects it |
| Comment `/ok-to-test` as `cadet` | Only an allowed user's approval counts |
| Put `OWNERS` on the branch `docs-typo` | Pipelines-as-Code reads `OWNERS` from `main` only |
| Change only the Secret, or only the webhook | The two secrets still differ; every event is still dropped |
| Restart the controller | The secrets still differ; a restart changes nothing |

## Common mistakes

- Reading Gitea's webhook deliveries and seeing `202`. The signature check comes after the answer.
- Waiting for the old pull request event after the fix. It was dropped; the `/ok-to-test` comment is the new event.
- Expecting `/retest` to work as approval for an outside contributor. Use `/ok-to-test`.

## Practice on your own

- Remove `cadet` from `OWNERS`, push a commit as `cadet`, and read the pending status `Pending approval, waiting for an /ok-to-test` and the comment.
- Set `remember-ok-to-test: "true"` in the ConfigMap `pipelines-as-code` and compare.
