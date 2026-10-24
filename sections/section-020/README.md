# Section 020: The .tekton Directory And Event Matching

A connected repository sends every push and every pull request to Pipelines-as-Code. What runs for each event is up to the files in the repository's `.tekton` folder. Each of them is a PipelineRun template with annotations that act as a filter: this event, these branches, these paths. Getting the filter right is most of the daily work with Pipelines-as-Code, and getting it wrong is the most common reason why "nothing ran".

You first learn how Pipelines-as-Code reads the folder and turns a template into a PipelineRun, with dynamic variables such as `{{ revision }}` that put the event's commit into the run. Then you match events and branches with `on-event` and `on-target-branch`, including branch globs and tags. Last, you meet the tools for harder rules (CEL expressions and path changes), the rule about duplicate names, remote tasks, and the cleanup of old runs with `max-keep-runs`.

**Topic covered:** Event matching

## What you will learn

- Where Pipelines-as-Code reads `.tekton` from, and what it changes in a template before it creates a PipelineRun.
- Dynamic variables: `{{ revision }}`, `{{ repo_url }}`, `{{ source_url }}`, `{{ target_branch }}` and others.
- `on-event` and `on-target-branch` for `pull_request` and `push` events, branch globs and tags.
- `on-cel-expression`, and why it overrides the other matching annotations.
- `on-path-change`, `on-path-change-ignore` and `.pathChanged()`.
- Duplicate PipelineRun names, remote tasks, and `max-keep-runs`.

## The learning path

The section has one module. It has a landing page, three short parts, a graded lab right after the part it tests, and a summary. The module also has its own playground, a cluster where you can explore freely, and the landing page starts it for you.

### 1. Write Pipelines In The .tekton Directory

The module starts at its landing page, which also launches the playground. The playground runs Tekton Pipelines, Pipelines-as-Code and a Gitea server, with `starfleet/bridge-app` already connected and a pull request template and a push template in its `.tekton` folder.

1. The .tekton Directory And Dynamic Variables
2. Match Events And Branches With Annotations, followed by the lab **Fix The Event Matching Of A Pull Request Pipeline**
3. CEL Expressions, Path Changes And Cleanup
4. Summary

## Section capstone: Route Push Pipelines By Branch

The capstone is one graded scenario that combines the whole module. The push pipeline of `starfleet/bridge-app` never runs: a CEL expression for the wrong branch overrides its annotations, and an old copy of the file reuses its name. Fix the `.tekton` folder so that pushes to `main` and to release branches run the push pipeline, other branches do not, and only three runs are kept. The grader pushes to three branches to check it. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS128.git -c sections/section-020/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-128-capstone-020
```
