# ATS128 — Pipelines-as-Code & Git-Native CI (Tekton)

Course material for the **Pipelines-as-Code & Git-Native CI** domain of the
Astrona Tekton training path ([ATP024](https://github.com/astrona-io/ATP024)),
which is **15% of the path**. Written for **Pipelines-as-Code v0.52.0** (and
its `tkn pac` plugin), **Tekton Pipelines v1.17.1** and the **tkn CLI
v0.46.2**, with **Gitea 28.2.0** as the in-cluster Git provider.

> **Status: draft, not yet run.** Every page, playground and lab was written
> from the Pipelines-as-Code documentation, the v0.52.0 release manifest and
> the source at the pinned tag. None has been started on a cluster, and no
> lab has passed `astrona test` yet. See `CLAUDE.md`.

Tekton is an incubating project of the Cloud Native Computing Foundation
(CNCF) since March 2026; before that it was a graduated project of the
Continuous Delivery Foundation. Pipelines-as-Code is one of its projects.
There is no official Tekton certification exam; the path's domains and
weights are Astrona's own.

**Why Gitea and not GitHub.** The domain covers GitHub Apps and GitHub
webhooks, and the pages teach both. The labs, however, must run on a laptop
without accounts or public webhook URLs, so every environment runs its own
Gitea server inside the cluster. Pipelines-as-Code supports Gitea (and
Forgejo) as a webhook provider with a token and a webhook secret; Gitea commit
statuses take the place of GitHub checks.

The course opens with an Introduction in `sections/intro/` (welcome, machine setup,
how the course is made). Everything else lives under `sections/`. Each section
contains:

- **Modules** — a reading chapter split into a short landing page, ordered
  deep-dive parts and a summary page, a throwaway **playground** to explore in,
  and a graded **lab** placed right after the part it tests.
- **A capstone** — one larger graded lab combining that section's modules into a
  single scenario with several independent faults.

---

## Sections

| Section | Title | Modules | Labs | Topic |
| --- | --- | --- | --- | --- |
| [010](sections/section-010) | Install Pipelines-as-Code And Connect A Repository | 1 | 1 + capstone | Concepts and installation |
| [020](sections/section-020) | The .tekton Directory And Event Matching | 1 | 1 + capstone | Event matching |
| [030](sections/section-030) | Pull Request Status, Concurrency And Access Control | 1 | 1 + capstone | Status, concurrency, access control |

The order follows the life of a repository. Section 010 installs
Pipelines-as-Code and connects a repository, so a pull request starts its
first PipelineRun. Section 020 writes the PipelineRuns in `.tekton` and
decides which events and branches start them. Section 030 looks at what
surrounds a run: the status reported to the pull request, the queue, and who
is allowed to start a run.

---

## Modules

| Module | Reader | Parts | Labs |
| --- | --- | --- | --- |
| 010-01 | [Connect A Git Repository To Pipelines-as-Code](sections/section-010/module-01/course.md) | 3 | [lab-01](sections/section-010/module-01/labs/lab-01) |
| 020-01 | [Write Pipelines In The .tekton Directory](sections/section-020/module-01/course.md) | 3 | [lab-01](sections/section-020/module-01/labs/lab-01) |
| 030-01 | [Control How Pipeline Runs Report, Queue And Start](sections/section-030/module-01/course.md) | 3 | [lab-01](sections/section-030/module-01/labs/lab-01) |

| Lab | Title | Kind | Faults or work |
| --- | --- | --- | --- |
| 010-01 | Connect A Gitea Repository To Pipelines-as-Code | build | install v0.52.0, Secret, `Repository`, Gitea webhook, open a pull request |
| 020-01 | Fix The Event Matching Of A Pull Request Pipeline | troubleshooting | `on-event: "[pull-request]"`, `on-target-branch: "[master]"`, a fixed `revision: main` |
| 030-01 | Queue Pull Request Runs With concurrency_limit | build | two pipelines run in parallel; set `concurrency_limit: 1` and run them again |

---

## Capstones

| Capstone | Scenario | Faults |
| --- | --- | --- |
| [010](sections/section-010/capstone/labs/lab-01) | Repair A Broken Repository Connection | an old `Repository` for the same URL in `default`, the token under the wrong Secret key, the webhook on the container port 8082 |
| [020](sections/section-020/capstone/labs/lab-01) | Route Push Pipelines By Branch | a CEL expression for the wrong branch that overrides the annotations, a duplicate PipelineRun name, no `max-keep-runs` |
| [030](sections/section-030/capstone/labs/lab-01) | Gate An Outside Contributor's Pull Request | a mismatched webhook secret, a fork pull request that needs `/ok-to-test`, trust through `OWNERS` instead of write access |

---

## The lab environment

Every playground and lab is a single-node **kind** cluster with `tkn` 0.46.2
and `tkn-pac` 0.52.0 on the machine. Tekton Pipelines v1.17.1 is installed
from its release manifest, and Pipelines-as-Code v0.52.0 from its
`release.k8s.yaml`, except in the section 010 playground and lab, where
installing it is the lesson. The namespace `gitea` runs Gitea
(`gitea/gitea:28.2.0-rootless`, HTTP only, lab-only users `starfleet` and
`cadet`) and a `tester` pod (`nicolaka/netshoot:v0.13`) for API calls. The
repository `starfleet/bridge-app` is seeded from each environment's
`manifests/repo/` folder. Pipeline steps use `alpine/git:v2.52.0` and
`busybox:1.37.0`. All four images are preloaded on the node; Tekton's and
Pipelines-as-Code's own images come from `ghcr.io` and `cgr.dev`, so every
start needs outbound internet.

Graders read Kubernetes objects with `kubectl` and the Gitea API from the
`tester` pod. Several graders push commits of their own (to `main`,
`release-1.0`, `feature-engines`, or as `cadet`) to test matching, cleanup and
trust. No script uses a fixed host port.

## Running a playground

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS128.git -c sections/<section>/<module>/playground
astrona destroy <name>
```

## Running a lab

Labs and capstones are graded. Read `question.md`, do the work, and submit:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS128.git -c sections/<section>/<module>/labs/lab-01
astrona submit -c sections/<section>/<module>/labs/lab-01
astrona destroy <name>
```

Each lab grades the **final cluster and Git state** with independent checks,
and several of them deliberately reject the plausible-but-wrong fix (a fixed
revision instead of `{{ revision }}`, retargeting the pull request, a second
`Repository` for the same URL, a webhook on the container port, giving the
contributor write access instead of an `OWNERS` entry).
