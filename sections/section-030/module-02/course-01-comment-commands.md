# Comment Commands On A Pull Request

A comment on a pull request can control the runs of that pull request. Pipelines-as-Code reads comments that start with a slash command. This lets a reviewer start a run again without pushing an empty commit, choose a single pipeline, or stop a run that is no longer needed.

## The commands

| Comment | Effect |
| --- | --- |
| `/retest` | Runs again only the pipelines that failed |
| `/retest <name>` | Forces the pipeline with that name to run again, even if it succeeded |
| `/test` | Starts the pipelines of the pull request on request |
| `/test <name>` | Forces the named pipeline to run, even if it succeeded |
| `/cancel` | Cancels the running pipelines of the pull request |
| `/cancel <name>` | Cancels only the named pipeline |
| `/ok-to-test` | Allows runs for a pull request from a user who has no rights |

The name is the `metadata.name` of the PipelineRun template, the same name that the label `pipelinesascode.tekton.dev/original-prname` holds. The commands are matched at the start of the comment text.

<!-- astrona:playground:renew -->

Create a branch with a change and open a pull request as `starfleet`, then list the runs:

```sh
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/original-prname
```

Two runs appear, `lint` and `unit-test`. Write a comment on the pull request through the Gitea API. Replace `1` with the number of your pull request:

```sh
kubectl -n gitea exec deploy/tester -- curl -sS -u starfleet:starfleet-password \
  -X POST -H 'Content-Type: application/json' --data '{"body":"/test lint"}' \
  http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/bridge-app/issues/1/comments
```

Then list the runs again. A new `lint` run appears, and no new `unit-test` run, because `/test lint` names one template. Write `/cancel` while a run is going and read the result:

```sh
kubectl get pipelineruns -n starfleet -L pipelinesascode.tekton.dev/original-prname
```

A cancelled run shows a reason of cancelled. The run is not deleted, and its logs stay until `max-keep-runs` removes it.

## What a restart uses

A restart takes the head commit of the pull request at the time of the comment. If someone pushed a new commit since the last run, the new run tests that commit. A restart of a push event is done with a comment on the commit, or by pushing again. The same commands work on a comment of a commit, in providers that support it.

## Who may use the commands

A comment is checked against the same rules as a pull request. The commands work for the owner of the repository, for collaborators and for members of an organization that has rights on the repository. A comment from a user without rights is ignored, except that the controller may answer with a note that the user is not allowed.

The `/ok-to-test` command is for a pull request from someone who is not allowed to start runs. Until an allowed user writes it, no pipeline starts for that pull request. This protects the cluster from a stranger who adds a malicious step to a template. Read the pull request first, then approve.

Try it with the second user of the playground. As `cadet`, fork the repository and open a pull request. Nothing runs. Comment `/ok-to-test` as `cadet`, and still nothing runs. Comment `/ok-to-test` as `starfleet`, and the pipelines start.

## Statuses and comments

For each run, the controller posts a commit status. For long-running or failed runs, it can also add a comment with the result. The status name is the application name from the global ConfigMap followed by the PipelineRun name. A reviewer reads the status in the pull request and uses the commands to act on it.

## Common pitfalls

> [!WARNING]
> - **Commenting `/ok-to-test` from the author of the pull request.** The command has an effect only when an allowed user writes it.
> - **A typo in the template name.** `/test lintt` matches no template, and no run starts.
> - **Expecting `/retest` to rerun a cancelled step.** It creates a new PipelineRun and does not resume the old one.
> - **Approving without reading.** `/ok-to-test` runs the template of the pull request with the Secrets of the namespace, unless the Repository uses the default branch as the source of definitions.
