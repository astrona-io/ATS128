---
estimated_duration: 25m
---

# Fix The Event Matching Of A Pull Request Pipeline

- **ID:** LAB
- **Slug:** ats-128-lab-020-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for the namespace `starfleet` and the Gitea repository `starfleet/bridge-app`. Read `question.md` for the task; `solution.md` is the walkthrough.

Not yet run: this lab was written from the Pipelines-as-Code v0.52.0
documentation, manifest and source and has not passed `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-128-lab-020-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-128-lab-020-01`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn, tkn-pac, Tekton Pipelines, Pipelines-as-Code, Gitea; then the faulty template, the connection and pull request #1 |
| `manifests/` | Namespaces, Gitea and tester; `repo/` with the faulty `.tekton/pull-request.yaml`; `branches/feature-shields/`; the `Repository` |
| `solution/` | Reference solution used by `astrona test`, with the fixed `pull-request.yaml` |
| `testing/` | Waits for Tekton, Pipelines-as-Code and Gitea |
| `validation/` | Grading scripts, one per check |
