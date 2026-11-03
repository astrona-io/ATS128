# Act On Runs From The Command Line

Comments are one way to control runs. The cluster gives you others, and you need them when the Git server is not available or when you want to inspect a run in detail. This part shows how to list, read, cancel and clean up runs with `tkn`, `tkn pac` and `kubectl`, and what each command changes.

## List and describe

The plugin groups runs by repository. List the repositories and the latest run of each, then describe one:

<!-- astrona:playground:renew -->

```sh
tkn pac list -n starfleet
tkn pac describe bridge-app -n starfleet
```

The description lists recent runs with their result, duration and commit. For the Tekton view of the same runs, use `tkn`:

```sh
tkn pipelinerun list -n starfleet
```

## Read the logs

`tkn pipelinerun logs` prints the logs of one run, and `--last` selects the newest. The plugin has its own command, which selects by repository:

```sh
tkn pipelinerun logs --last -n starfleet
tkn pac logs bridge-app -n starfleet --last
```

Add `-f` to follow a running run. A step that already finished is printed in full.

## Cancel a run

The comment `/cancel` asks the controller to cancel. You can do the same from the cluster with `tkn`:

```sh
tkn pipelinerun cancel <PIPELINERUN> -n starfleet
```

Replace `<PIPELINERUN>` with a name from the list. Tekton stops the pods and sets the reason of the run to cancelled. The watcher reports the result to the Git server, and the commit status changes.

## Clean up

Old runs stay until `max-keep-runs` removes them. To remove one by hand, delete the object:

```sh
tkn pipelinerun delete <PIPELINERUN> -n starfleet
```

The command asks for confirmation. Deleting a run does not remove its commit status in the Git server, and the history in the `Repository` is trimmed by the watcher over time.

## Start again without a comment

You cannot create a PipelineRun by hand and expect Pipelines-as-Code to report it, because the status link depends on labels and annotations that the controller sets. To run again, use a comment, push a new commit, or call an incoming webhook for a template that supports it.

## Common pitfalls

> [!WARNING]
> - **Cancelling a run in the cluster and expecting a comment.** The status changes, but no explanation is posted.
> - **Deleting a run to restart it.** Delete removes the object, and no new run starts.
> - **Copying an old run YAML to restart.** The labels point at an old state, and reports may go to the wrong commit.
> - **Reading logs of a pruned run.** The pods are gone once the run is removed.
