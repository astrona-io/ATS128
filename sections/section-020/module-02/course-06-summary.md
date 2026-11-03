# Summary

A template describes the steps, and the Repository, the event and the cluster supply the values. When a value is wrong, the first question is which of the three supplied it.

## What you learned

Dynamic variables such as `{{ revision }}`, `{{ source_branch }}`, `{{ event_type }}` and `{{ sender }}` come from the event. Custom parameters are defined in the `Repository` under `params`, can be limited with a CEL `filter`, and can read a Secret with `secret_ref`. A variable with no value stays as literal text in the PipelineRun.

A parameter from `secret_ref` is stored in the PipelineRun, so a Secret mounted by the Pipeline protects the value better. The variable `{{ git_auth_secret }}` names a Secret with the provider token for cloning a private repository.

Tasks and Pipelines can come from the `.tekton` folder, from a URL or from a catalog. The annotations `task` and `pipeline` name the source, and the ConfigMap keys `remote-tasks` and `hub-url` allow and locate remote ones. `tkn pac resolve -f <file> -p <name>=<value> --no-secret` shows the PipelineRun the controller would build. The key facts to remember are these:

- Values from `params` are fixed when the PipelineRun is created.
- Do not write a secret value into `value`.
- Pin remote Tasks to a tag or a commit.
- A failed match, a failed creation and a failed step are read in three different places.

<!-- astrona:playground:destroy -->
