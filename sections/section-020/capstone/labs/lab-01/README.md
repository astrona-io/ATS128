---
estimated_duration: 35m
---

# Route Push Pipelines By Branch

- **ID:** CAPSTONE
- **Slug:** ats-128-capstone-020
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded capstone

Graded capstone for section 020, in the namespace `starfleet` and the Gitea repository `starfleet/bridge-app`. Read `question.md` for the task; `solution.md` is the walkthrough.

> **Not yet run.** This capstone was written from the Pipelines-as-Code
> v0.52.0 documentation, manifest and source and has not passed `astrona test` yet.

The graders commit files under `grader/` to `main`, `release-1.0` and `feature-engines` to test the routing and the cleanup.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-128-capstone-020
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-128-capstone-020`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn, tkn-pac, Tekton Pipelines, Pipelines-as-Code, Gitea; then the repository with the faulty `.tekton`, two branches and the connection |
| `manifests/` | Namespaces, Gitea and tester; `repo/` with `push.yaml` (wrong CEL) and `push-copy.yaml` (duplicate name); the `Repository` |
| `solution/` | Reference solution used by `astrona test`, with the fixed `push.yaml` |
| `testing/` | Waits for Tekton, Pipelines-as-Code and Gitea |
| `validation/` | Grading scripts, one per check |
