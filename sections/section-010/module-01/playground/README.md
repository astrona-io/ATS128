# Connect A Git Repository To Pipelines-as-Code — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-128-playground-010-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single sandbox environment with Tekton Pipelines v1.17.1, Gitea 28.2.0 with the seeded repository `starfleet/bridge-app` (`.tekton/pull-request.yaml` on `main`, branch `feature-hello`), the tkn CLI 0.46.2 and tkn-pac 0.52.0. Pipelines-as-Code is **not** installed: the reader installs it. Nothing to submit.

Not yet run: this playground was written from the documentation and the
v0.52.0 release manifest and has not been started on a cluster yet.

## Run it

```sh
astrona run -c .
astrona destroy ats-128-playground-010-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-128-playground-010-01`), not
the config path. `astrona submit` and `astrona test` do not apply — there is no
grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime + bootstrap only) |
| `bootstrap/prepare.sh` | tkn, tkn-pac, Tekton Pipelines, Gitea users and token, repository seed |
| `manifests/lab-start.yaml` | The namespaces `starfleet` and `gitea`, Gitea and the tester pod |
| `manifests/repo/` | Files seeded into `main` of `starfleet/bridge-app` |
| `manifests/branches/` | Files committed to the branch `feature-hello` |
| `docs/overview.md` | What the environment contains and ideas to try |
