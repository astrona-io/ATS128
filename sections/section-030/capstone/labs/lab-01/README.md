---
estimated_duration: 40m
---

# Gate An Outside Contributor's Pull Request

- **ID:** CAPSTONE
- **Slug:** ats-128-capstone-030
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded capstone

Graded capstone for section 030, in the namespace `starfleet` and the Gitea repositories `starfleet/bridge-app` and `cadet/bridge-app` (a fork). Read `question.md` for the task; `solution.md` is the walkthrough.

> **Not yet run.** This capstone was written from the Pipelines-as-Code
> v0.52.0 documentation, manifest and source and has not passed `astrona test` yet.
> It depends on a pull request from a fork; see the open risks in `CLAUDE.md`.

The grader `validate-trusted-contributor` pushes a commit as `cadet` to the fork's branch `docs-typo`.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-128-capstone-030
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-128-capstone-030`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn, tkn-pac, Tekton Pipelines, Pipelines-as-Code, Gitea users `starfleet` and `cadet`; then the repository, the mismatched webhook secret, the fork and pull request #1 |
| `manifests/` | Namespaces, Gitea and tester; `repo/`; `branches/docs-typo/` (cadet's change); the `Repository` |
| `solution/` | Reference solution used by `astrona test`, with the `OWNERS` file |
| `testing/` | Waits for Tekton, Pipelines-as-Code and Gitea |
| `validation/` | Grading scripts, one per check |
