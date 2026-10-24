---
estimated_duration: 20m
---

# Queue Pull Request Runs With concurrency_limit

- **ID:** LAB
- **Slug:** ats-128-lab-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for the namespace `starfleet` and the Gitea repository `starfleet/bridge-app`. Read `question.md` for the task; `solution.md` is the walkthrough.

Not yet run: this lab was written from the Pipelines-as-Code v0.52.0
documentation, manifest and source and has not passed `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-128-lab-030-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-128-lab-030-01`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn, tkn-pac, Tekton Pipelines, Pipelines-as-Code, Gitea; then the repository, the connection, pull request #1 and its first two runs |
| `manifests/` | Namespaces, Gitea and tester; `repo/` with `lint.yaml` and `unit-test.yaml`; `branches/feature-sensors/`; the `Repository` |
| `solution/` | Reference solution used by `astrona test`, with the `Repository` and a file to commit |
| `testing/` | Waits for Tekton, Pipelines-as-Code and Gitea |
| `validation/` | Grading scripts, one per check |
