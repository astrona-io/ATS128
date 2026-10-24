# Match Events And Branches With Annotations

A repository usually holds several PipelineRuns: one for pull requests, one for pushes to the main branch, maybe one for release tags. Each Git event must start the right ones and nothing else. Pipelines-as-Code decides this from annotations on each PipelineRun in `.tekton`. This part covers the two annotations that almost every PipelineRun has, and the patterns they accept.

## on-event and on-target-branch

Event matching is the step where the pipelines-as-code-controller compares an event with each PipelineRun in `.tekton` and keeps the ones that match. The two basic annotations are:

- `pipelinesascode.tekton.dev/on-event`: the kinds of event, in square brackets, such as `"[pull_request]"`, `"[push]"` or `"[pull_request, push]"`.
- `pipelinesascode.tekton.dev/on-target-branch`: the branches the event targets, such as `"[main]"` or `"[main, release-*]"`.

For a pull request, the target branch is the branch the pull request merges into, not the branch it comes from. For a push, it is the branch that received the commits. A PipelineRun needs both annotations to match; a PipelineRun with only one of them never runs (the only ways around this are a CEL expression and comment matching). When several PipelineRuns match one event, the controller creates all of them, and they run in parallel.

The event names are fixed words. `pull_request` covers a pull request that was opened, reopened or updated with new commits; Gitea also sends `pull_request` events when the labels of a pull request change and when it is closed; Pipelines-as-Code handles those separately (for example with label matching). `push` covers pushed commits and tags. A spelling such as `pull-request` matches nothing, and Pipelines-as-Code does not warn you: the event simply finds no PipelineRun.

<!-- astrona:playground:renew -->

See both annotations work in your playground. Create a branch and open a pull request from it into `main`:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X POST -H 'Content-Type: application/json' \
  http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/branches --data '{"new_branch_name":"feature-docs","old_branch_name":"main"}'
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password -X POST -H 'Content-Type: application/json' \
  http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/pulls --data '{"head":"feature-docs","base":"main","title":"Improve the docs"}'
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/original-prname,pipelinesascode.tekton.dev/event-type
```

After a few seconds the list shows a new run of `pull-request` with the event type `pull_request`, and no new run of `push`: the push template says `[push]`, and opening a pull request is not a push. Creating the branch itself started nothing either, because the branch `feature-docs` is not in the push template's `on-target-branch`.

## Branch patterns

`on-target-branch` accepts more than plain names. Pipelines-as-Code compares full Git references, such as `refs/heads/main` for the branch `main` and `refs/tags/v1.0` for the tag `v1.0`. A short name like `main` is expanded to `refs/heads/main` first, so `[main]` and `[refs/heads/main]` mean the same. Patterns are globs (not regular expressions): `*` matches any characters, so `[main, release-*]` matches `main`, `release-1.0` and `release-2.3`, and `[refs/heads/*]` matches every branch.

Tags are pushes too. A PipelineRun for release tags uses `on-event: "[push]"` and a tag reference:

```yaml
metadata:
  name: release
  annotations:
    pipelinesascode.tekton.dev/on-event: "[push]"
    pipelinesascode.tekton.dev/on-target-branch: "[refs/tags/v*]"
```

Test a pattern before you commit it. `tkn pac info globbing` with `-s` compares a pattern with a string:

```sh
tkn pac info globbing -s "refs/heads/release-1.0" "refs/heads/release-*"
tkn pac info globbing -s "refs/heads/feature-docs" "refs/heads/release-*"
```

The first command reports a match, the second does not.

## Change a template in a pull request

Because Pipelines-as-Code reads `.tekton` from the pull request's own branch, you can try a new rule in a pull request before it reaches `main`. Change the pull request template on `feature-docs` so that it also runs for pull requests into release branches. Fetch the file, change one line, and commit it to the branch with a helper that creates or updates a file through the Gitea API:

```sh
gitea_put_file() {
  local branch="$1" file="$2" path="$3" message="$4" sha method body
  sha="$(kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password "$1" | jq -r ".sha // empty"' \
    _ "http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/contents/$path?ref=$branch")"
  body="{\"branch\":\"$branch\",\"message\":\"$message\",\"content\":\"$(base64 < "$file" | tr -d '\n')\""
  if [ -n "$sha" ]; then method=PUT; body="$body,\"sha\":\"$sha\"}"; else method=POST; body="$body}"; fi
  kubectl -n gitea exec deploy/tester -- sh -c 'curl -sS -u starfleet:starfleet-password -X "$1" -H "Content-Type: application/json" --data "$2" "$3" | jq -r ".commit.sha"' \
    _ "$method" "$body" "http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/contents/$path"
}
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  "http://gitea-http.gitea:3000/api/v1/repos/starfleet/bridge-app/raw/.tekton/pull-request.yaml?ref=feature-docs" > pull-request.yaml
sed -i.bak 's/on-target-branch: "\[main\]"/on-target-branch: "[main, release-*]"/' pull-request.yaml
gitea_put_file feature-docs pull-request.yaml .tekton/pull-request.yaml "Also test pull requests into release branches"
```

The commit updates the pull request, so Gitea sends a `pull_request` event (an update with new commits), and a second run of `pull-request` starts for the new head commit. Its annotations in the cluster show the new rule:

```sh
kubectl get pipelineruns -n starfleet -l pipelinesascode.tekton.dev/original-prname=pull-request \
  -o jsonpath='{range .items[*]}{.metadata.name} {.metadata.annotations.pipelinesascode\.tekton\.dev/on-target-branch}{"\n"}{end}'
```

The older run shows `[main]`, the newer one `[main, release-*]`. Pipelines-as-Code copies the template's annotations onto each PipelineRun, which makes them a good place to check which version of a template ran.

You can now choose the events and branches of each PipelineRun, with globs for families of branches and `refs/tags/` for tags. The open question is what to do when a rule needs more than an event and a branch.

## Common pitfalls

> [!WARNING]
> - **`pull-request` instead of `pull_request`.** The event name has an underscore. A wrong name matches nothing and logs no error on the pull request.
> - **Only one of the two annotations.** A PipelineRun with `on-event` but no `on-target-branch` never runs.
> - **Thinking `on-target-branch` is the source branch.** For a pull request it is the branch the pull request merges into.
> - **Regular expressions in `on-target-branch`.** The patterns are globs: `release-*`, not `release-.*`.
> - **Fixing the template on `main` for an open pull request.** The pull request uses its own branch's `.tekton`. Change the file on that branch, or merge `main` into it.

## Your mission: Fix The Event Matching Of A Pull Request Pipeline

You can now read and fix the matching annotations of a PipelineRun, and you know where Pipelines-as-Code reads them from. The graded lab gives you a pull request that never starts a run, because its template has the wrong event, the wrong branch and a fixed revision, and asks you to fix the template so the pull request tests its own commit.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-128-playground-020-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS128.git -c sections/section-020/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-128-lab-020-01
astrona start ats-128-playground-020-01
```
