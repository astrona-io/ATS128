---
estimated_duration: 35m
---

# Repair A Broken Repository Connection

- **ID:** CAPSTONE
- **Slug:** ats-128-capstone-010
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded capstone

Graded capstone for section 010, in the namespaces `starfleet`, `default`, `pipelines-as-code` and `gitea`. Read `question.md` for the task; `solution.md` is the walkthrough.

> **Not yet run.** This capstone was written from the Pipelines-as-Code
> v0.52.0 documentation, manifest and source and has not passed `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-128-capstone-010
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-128-capstone-010`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn, tkn-pac, Tekton Pipelines, Pipelines-as-Code, Gitea; then the repository, three faults and pull request #1 |
| `manifests/` | Namespaces, Gitea and tester; `repo/`; `branches/feature-hello/`; the old `Repository` in `default` |
| `solution/` | Reference solution used by `astrona test`, with the `Repository` that reads the key `token` |
| `testing/` | Waits for Tekton, Pipelines-as-Code and Gitea |
| `validation/` | Grading scripts, one per check |
