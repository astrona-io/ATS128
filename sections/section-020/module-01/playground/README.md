# Write Pipelines In The .tekton Directory — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-128-playground-020-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single sandbox environment with Tekton Pipelines v1.17.1, Pipelines-as-Code v0.52.0, Gitea 28.2.0, the tkn CLI 0.46.2 and tkn-pac 0.52.0. The repository `starfleet/bridge-app` holds `.tekton/pull-request.yaml` and `.tekton/push.yaml` and is connected (Secret `gitea-webhook-config`, `Repository` `bridge-app`, Gitea webhook). Nothing to submit.

Not yet run: this playground was written from the documentation and the
v0.52.0 release manifest and has not been started on a cluster yet.

## Run it

```sh
astrona run -c .
astrona destroy ats-128-playground-020-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-128-playground-020-01`), not
the config path. `astrona submit` and `astrona test` do not apply — there is no
grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime + bootstrap only) |
| `bootstrap/prepare.sh` | tkn, tkn-pac, Tekton Pipelines, Pipelines-as-Code, Gitea, repository seed and connection |
| `manifests/lab-start.yaml` | The namespaces `starfleet` and `gitea`, Gitea and the tester pod |
| `manifests/repo/` | Files seeded into `main` of `starfleet/bridge-app` |
| `manifests/repository-bridge-app.yaml` | The `Repository` `bridge-app` |
| `docs/overview.md` | What the environment contains and ideas to try |
