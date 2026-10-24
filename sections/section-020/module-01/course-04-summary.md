# Summary

Every file in the `.tekton` folder is a PipelineRun template, and its annotations decide which Git events start it. Pipelines-as-Code reads the folder, picks the matching templates, fills in the event's values and creates the PipelineRuns.

## What you learned

The pipelines-as-code-controller reads `.tekton` (and its subfolders) from the commit of the event, so a pull request is tested with its own version of the pipelines; `pipelinerun_provenance: default_branch` in the `Repository` changes that to the default branch. It combines each matching PipelineRun with the Pipelines and Tasks it references, uses its name as `generateName`, and keeps the original name in the label `pipelinesascode.tekton.dev/original-prname`.

Dynamic variables such as `{{ revision }}`, `{{ repo_url }}`, `{{ source_url }}`, `{{ target_branch }}` and `{{ pull_request_number }}` are filled in by Pipelines-as-Code before the PipelineRun exists; Tekton variables such as `$(params.revision)` are filled in later by Tekton. A template that writes a fixed branch instead of `{{ revision }}` tests the wrong commit.

Matching starts with two annotations that a PipelineRun needs together: `on-event` (`pull_request`, `push`) and `on-target-branch` (the branch the pull request merges into, or the branch that received the push). Branch values are globs on full references, so `[main, release-*]` and `[refs/tags/v*]` work. `on-cel-expression` replaces all other matching annotations when it is present. `on-path-change`, `on-path-change-ignore` and `.pathChanged()` limit a run to certain files.

Two details can stop runs without a visible error on the pull request: a misspelled event name, and two PipelineRuns with the same name. `max-keep-runs` lets the watcher delete old finished runs of a template. The key facts to remember are these:

- Both `on-event` and `on-target-branch` are needed, unless a CEL expression is used.
- A CEL expression overrides every other matching annotation.
- Duplicate names in `.tekton` stop every run for the event.
- `max-keep-runs` counts runs per `Repository` and template name.

<!-- astrona:playground:destroy -->
