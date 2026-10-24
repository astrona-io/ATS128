---
estimated_duration: 30m
---

# Connect A Gitea Repository To Pipelines-as-Code

- **ID:** LAB
- **Slug:** ats-128-lab-010-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for the namespaces `starfleet`, `pipelines-as-code` and `gitea`. Read `question.md` for the task; `solution.md` is the walkthrough.

Not yet run: this lab was written from the Pipelines-as-Code v0.52.0
documentation, manifest and source and has not passed `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-128-lab-010-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-128-lab-010-01`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn, tkn-pac, Tekton Pipelines, Gitea user and token (no Pipelines-as-Code), then the repository seed |
| `manifests/` | Namespaces, Gitea and tester; `repo/` seeded into `main`; `branches/feature-hello/` |
| `solution/` | Reference solution used by `astrona test`, with the `Repository` |
| `testing/` | Waits for Tekton, Pipelines-as-Code and Gitea |
| `validation/` | Grading scripts, one per check |
