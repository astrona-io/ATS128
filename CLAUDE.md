# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls` and the mission. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-0N-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **The space theme is only for examples.** Space appears in two places and
  nowhere else: the names of the example workloads (the Starfleet: `bridge`,
  `scout`, `shuttle`, `probe`, the `starfleet` and `outpost` namespaces) and
  the short scenario that opens a lab task or a practice exercise (for
  example "the `drifter` in `outpost` must keep reaching the probe"). The
  explanation around an example is plain technical text: write "the
  `shuttle` pod sends a request to the `probe` Service", never "the shuttle
  sends a signal to the probe ship". Do not address the reader as an
  astronaut, and do not use space metaphors (communications officer, mission
  control, badge, airlock, guest list, star chart) for Istio or Kubernetes
  concepts. Titles of pages and labs name the technical task ("Require mTLS
  With PeerAuthentication"), not a space story.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Use a Mermaid
  diagram for a flow, an order or a state change, keep it under about 12
  boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. That part then ends with a `## Your mission: <lab title>` section:
  one sentence on what the reader can now do, one on what the mission asks,
  then pause the playground (`astrona stop <playground name>`), the
  `astrona run` and `astrona submit` commands, and finally
  `astrona destroy <lab name>` plus `astrona start <playground name>`.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **Every course starts with an Introduction.** It lives in `sections/intro/`
  and is the first entry in `astrona.yaml` (`id: module-intro`, title
  "Introduction"). It has exactly these four pages, in this order:
  - `README.md`, `# Introduction`: what the introduction covers and its three
    pages, named in prose (no links), ending with the topic the course starts
    with.
  - `course-01-welcome.md`, `# Welcome To The Course`: who the course is for,
    the exam domain and what the reader can do at the end, the words the
    course uses, the example app, how the course is laid out and how to read
    a page.
  - `course-02-get-your-machine-ready.md`, `# Get Your Machine Ready`: the
    tools to install, the `astrona` commands used every day, and what to do
    when a start goes wrong.
  - `course-03-how-this-course-is-made.md`, `# How This Course Is Made`: how
    content is written and checked, the maintainers, how to report a mistake,
    and the license.
  The Introduction teaches no product content and has no playground, labs or
  summary. Its only links are the repository's contributors page, issues
  page and license.
- **No links to other course files.** A course page (every reading listed in
  `astrona.yaml`, the playground guide `docs/overview.md`, and a lab's
  `question.md` and `solution.md`) never links to or points the reader at
  another page or file of the repository: no links to parts, summaries,
  labs, `question.md`, other modules, sections or the Introduction, and no
  "see `practice.md`" or "open `config.yaml`". The platform shows the pages in
  the order of `astrona.yaml`, so a link only adds a second, often wrong,
  path. Name a thing in plain words when the reader needs it ("the task is on
  the next page"), and state a fact on the page itself instead of sending the
  reader somewhere else. Repository files for authors (the root `README.md`,
  a lab's or playground's `README.md`) may link.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Introduction's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.


## About this repo (ATS128 only)

Everything above is general and can be copied to other course repositories. This
section is only true for this one.

### What the student is trying to learn

- **The goal:** master the **Pipelines-as-Code & Git-Native CI** domain of the
  **Tekton** training path (`ATP024`). It is 15% of the path. There is no
  official Tekton certification exam; the path's domains and weights are
  Astrona's own, set in `ATP024/path.yaml` (10/20/25/15/15/15 for ATS124 to
  ATS129).
- **Where Tekton sits:** Tekton is an **incubating project of the Cloud Native
  Computing Foundation (CNCF)**. The CNCF accepted it on 13 March 2026. Before
  that it was a founding and graduated project of the Continuous Delivery
  Foundation (CD Foundation). It is **not** a CNCF graduated project, and it is
  no longer a CD Foundation project. Both foundations belong to the Linux
  Foundation. Pipelines-as-Code is one of the Tekton projects
  (`tektoncd/pipelines-as-code`). Say this correctly wherever the course
  mentions it.
- **What the domain really tests:** running Git-driven CI, not remembering
  words. The student must *do* things: install Pipelines-as-Code, connect a
  Git repository with a `Repository` object, a token and a webhook, write
  PipelineRuns in `.tekton/` that match the right events and branches, read
  the commit status that comes back, queue runs with `concurrency_limit`, and
  let an outside contributor's pull request run with `/ok-to-test` and an
  `OWNERS` file. Every fix is proved by a PipelineRun that Pipelines-as-Code
  created for a real Git event, whose `Succeeded` condition is `True`, and by
  the commit status in the Git server.
- **The three topics:** concepts and installation, the `.tekton` directory
  and event matching, and status, concurrency and access control. The README
  table maps each section to its topic.
- **The sections:**

  | Section | Title | Topic |
  | --- | --- | --- |
  | 010 | Install Pipelines-as-Code And Connect A Repository | Concepts and installation |
  | 020 | The .tekton Directory And Event Matching | Event matching |
  | 030 | Pull Request Status, Concurrency And Access Control | Status, concurrency, access control |

- **The versions:** everything is written for **Pipelines-as-Code v0.52.0**
  (the `tkn pac` plugin 0.52.0), **Tekton Pipelines v1.17.1** and the **tkn
  CLI v0.46.2** on a single-node `kind` cluster, with **Gitea 28.2.0**
  (`gitea/gitea:28.2.0-rootless`) as the Git server. Pipelines-as-Code v0.52.0
  needs Kubernetes 1.28 or later (the controller checks `KUBERNETES_MIN_VERSION`
  `v1.28.0`). Other Tekton versions are named only for orientation: Dashboard
  v0.73.0, Triggers v0.37.2, Chains v0.29.9, Operator v0.81.2, Pruner v0.4.4.
  Do not teach fields, flags or output from other versions without saying so.
- **The main sources:** the Pipelines-as-Code documentation (the
  `docs/content/docs/` folder of `tektoncd/pipelines-as-code` at tag
  `v0.52.0`, published at <https://pipelinesascode.com>), the release manifest
  `release.k8s.yaml` of v0.52.0, and the source at that tag (`pkg/provider/gitea`,
  `pkg/matcher`, `pkg/webhook`, `pkg/kubeinteraction`). Check every page
  against them.

### Status: built, not yet run

The first version of this repository was written from the documentation, the
release manifest and the source at the pinned tags **without a live run**. No
playground or lab has been started, and no `astrona test` has passed yet.
Until a maintainer runs them:

- Pages describe results in words. Do not add `text` output blocks until the
  output comes from a real run, and then paste it exactly.
- Treat every lab as unverified. Run `astrona validate` and `astrona test` on
  each one, one cluster at a time, before the course goes past `maturity:
  draft`.
- Remove this subsection when every lab has passed `astrona test`.

The biggest open risks are: whether Gitea 28.2.0 fills the `added`,
`modified` and `removed` lists of a push payload for commits made through the
API (path matching on push events relies on them; no graded lab depends on
it); whether Gitea serves `git/trees` of a fork's commit from the base
repository (the section 030 capstone runs a fork pull request); the exact
Gitea event names the hook API accepts (`push`, `pull_request`,
`pull_request_sync`, `pull_request_comment`); and image pulls of the
Pipelines-as-Code images from `ghcr.io` (`imagePullPolicy: Always`, not
preloaded).

### Why the labs use Gitea, not GitHub

The domain names GitHub Apps, but a lab cannot create a GitHub App, reach a
public webhook URL or use a real account. Pipelines-as-Code supports Gitea and
Forgejo as a webhook provider (`git_provider.type: forgejo`, with `gitea`
kept as an alias), so every lab runs an in-cluster Gitea. The pages teach
the GitHub App and the GitHub webhook in prose (what they need, what they
report, how they differ) and say plainly that the labs use Gitea because it
runs inside the cluster. Gitea's commit statuses play the role of GitHub's
checks.

### Terms, not metaphors

Explanations use the project's and Kubernetes' own words. Define each one in
plain technical language on first use in a file, for example:

| Term | First-use definition (example wording) |
| --- | --- |
| Pipelines-as-Code (PaC) | A Tekton project that runs PipelineRuns stored in a Git repository's `.tekton` folder when Git events happen |
| `.tekton` directory | The folder at the top of a repository that holds the PipelineRun templates Pipelines-as-Code reads |
| `Repository` (`pipelinesascode.tekton.dev/v1alpha1`) | A custom resource that connects one Git repository URL to a namespace, with the provider settings |
| Git provider | The Git hosting service: GitHub, GitLab, Bitbucket, Forgejo or Gitea |
| Webhook | An HTTP request a Git server sends to a URL when an event happens (push, pull request, comment) |
| Webhook secret | A shared string the Git server uses to sign each webhook; Pipelines-as-Code checks the signature (HMAC-SHA256) |
| GitHub App | A GitHub integration installed on repositories; it has its own ID and private key and uses the Checks API |
| Personal access token | A token of a user account that Pipelines-as-Code uses to call the provider's API |
| Commit status | A state (`pending`, `success`, `failure`) and a name that a tool attaches to one commit in the Git server |
| Dynamic variable | A `{{ name }}` placeholder that Pipelines-as-Code replaces before it creates the PipelineRun, such as `{{ revision }}` |
| Event matching | Choosing which PipelineRuns run for an event, through `on-event`, `on-target-branch`, `on-cel-expression`, `on-path-change` |
| `concurrency_limit` | The number of PipelineRuns of one `Repository` that may run at the same time; the rest wait in a queue |
| GitOps command | A pull request comment such as `/retest`, `/test <name>`, `/ok-to-test` or `/cancel` that Pipelines-as-Code acts on |
| `OWNERS` file | A file on the default branch whose `approvers` and `reviewers` may run pipelines |
| pipelines-as-code-controller | Receives webhooks, matches PipelineRuns and creates them |
| pipelines-as-code-watcher | Watches the PipelineRuns, reports their status to the Git provider, runs the concurrency queue and the cleanup |
| pipelines-as-code-webhook | The admission webhook that validates `Repository` objects (one per URL, valid URL) |
| `tkn pac` | The Pipelines-as-Code command-line tool, a `tkn` plugin (the program `tkn-pac`) |

A PipelineRun in the `.tekton` folder and the PipelineRun in the cluster are
the most confused pair. On first use in a file, say which one you mean: the
file is a template, and Pipelines-as-Code creates a new PipelineRun object
(with `generateName`) from it for each event.

### The example workloads

| Name | Image | What it is |
| --- | --- | --- |
| Namespace `starfleet` | | Holds the `Repository` `bridge-app`, the Secret `gitea-webhook-config` and every PipelineRun |
| Namespace `gitea` | | Gitea (Deployment and Service `gitea-http`, port `3000`), the `tester` pod and the Secret `gitea-token` |
| `gitea` | `gitea/gitea:28.2.0-rootless` | The in-cluster Git server. HTTP, SQLite on an `emptyDir`. `ROOT_URL` is `http://gitea-http.gitea.svc.cluster.local:3000/`; `ALLOWED_HOST_LIST=private` lets it call Services in the cluster |
| `tester` | `nicolaka/netshoot:v0.13` | Client pod with `curl` and `jq`. Scripts and graders call the Gitea API from it |
| Gitea user `starfleet` | | Password `starfleet-password`, site administrator, owner of the repository. Lab-only credentials; say so when a page uses them |
| Gitea user `cadet` | | Password `cadet-password`, no rights on the repository (section 030 playground and capstone) |
| Repository `starfleet/bridge-app` | | Public. `app/VERSION`, `app/status.sh`, `docs/guide.md` and the `.tekton` folder |
| `.tekton/pull-request.yaml` | `alpine/git:v2.52.0`, `busybox:1.37.0` | PipelineRun `pull-request`: clones `{{ source_url }}` at `{{ revision }}`, returns the result `commit`, runs `app/status.sh` |
| `.tekton/push.yaml` | same | PipelineRun `push` for pushes to `main`, `max-keep-runs: "3"` |
| `.tekton/lint.yaml`, `.tekton/unit-test.yaml` | same | Two pull request PipelineRuns of about 20 seconds each (section 030) |
| Branches `feature-hello`, `feature-shields`, `feature-sensors`, `feature-engines`, `release-1.0`, `docs-typo` | | Pull request and push branches. No slashes, so API paths stay simple |

Every step uses a `script`. The PipelineRun result `commit` (the output of
`git rev-parse HEAD`) is how graders prove that `{{ revision }}` was used.

### Environment facts the text must respect

- **Always call Gitea by its full name,**
  `http://gitea-http.gitea.svc.cluster.local:3000`. Gitea builds the clone and
  HTML URLs in a webhook payload from the `Host` of the API request that caused
  the event, not only from `ROOT_URL` (seen live: a pull request opened through
  `gitea-http.gitea:3000` sent that short URL). Pipelines-as-Code then finds no
  Repository, whose `spec.url` uses the full name, and starts nothing.
- **Clone steps mark the clone as safe.** The workspace folder belongs to a
  different user than the `alpine/git` step, so `git checkout` stops with
  `detected dubious ownership` unless the step first runs
  `git config --global --add safe.directory /workspace/source`.
- **Install from the release manifest:**
  `kubectl apply -f https://github.com/tektoncd/pipelines-as-code/releases/download/v0.52.0/release.k8s.yaml`
  (`release.yaml` in the same release is for OpenShift). The upstream page
  shows `.../stable/release.k8s.yaml`; the course pins the release asset.
- **What the release creates (checked in the v0.52.0 manifest):** namespace
  `pipelines-as-code`; Deployments `pipelines-as-code-controller` (container
  `pac-controller`, port `8082`), `pipelines-as-code-watcher` and
  `pipelines-as-code-webhook`; Service `pipelines-as-code-controller` with port
  **`8080`** (`http-listener`, target `8082`) and `9090` (metrics); CRD
  `repositories.pipelinesascode.tekton.dev` (short name `repo`, printer
  column `URL` only); ConfigMaps `pipelines-as-code` (settings),
  `pipelines-as-code-info` (`version: "v0.52.0"`, `controller-url`,
  `provider`), `pac-config-logging`; ValidatingWebhookConfiguration
  `validation.pipelinesascode.tekton.dev`. Images
  `ghcr.io/tektoncd/pipelines-as-code/pipelines-as-code-{controller,watcher,webhook}:v0.52.0`.
- **The `pipelines-as-code` ConfigMap defaults to know:** `application-name:
  "Pipelines as Code CI"` (the prefix of every commit status name),
  `secret-auto-create: "true"`, `remote-tasks: "true"`, `hub-url:
  "https://artifacthub.io"`, `enable-cancel-in-progress-on-pull-requests` and
  `...-on-push` `"false"`, `default-max-keep-runs` and
  `max-keep-run-upper-limit` empty, `remember-ok-to-test: "false"`,
  `require-ok-to-test-sha: "false"`, `skip-push-event-for-pr-commits: "true"`,
  `trusted-provider-hostnames: ""` (today it gates only the GitHub provider).
- **The Repository webhook (checked in `pkg/webhook/validation.go`):** rejects a
  second `Repository` with the same URL anywhere in the cluster ("repository
  already exists with URL: ..."), a URL whose scheme is not http or https, a
  user who cannot create PipelineRuns in the namespace, and
  `concurrency_limit: 0`. Bootstrap scripts wait until a dry run with an
  `ftp://` URL is refused with "scheme must be http or https".
- **Gitea provider (checked in `pkg/provider/gitea`):** events are detected by
  the header `X-Gitea-Event-Type`; the signature is `X-Forgejo-Signature` or
  `X-Gitea-Signature` (HMAC-SHA256); an empty webhook secret is refused. The
  Secret keys default to `provider.token` and `webhook.secret`. The commit
  status name is `<application-name> / <PipelineRun name>`, for example
  `Pipelines as Code CI / pull-request`; the state is `pending` while the run
  goes on ("CI has Started") and `success` or `failure` at the end. On pull
  requests Pipelines-as-Code also posts a comment. The controller answers a
  webhook with HTTP 202 before it checks the signature, so a wrong secret shows
  only in the controller log and the namespace events, not in Gitea's delivery.
- **Labels and annotations on a PipelineRun (checked in
  `pkg/kubeinteraction/labels.go`):** labels
  `pipelinesascode.tekton.dev/{repository,sha,event-type,state,url-org,url-repository,original-prname}`
  (and `pull-request` for pull requests), `app.kubernetes.io/managed-by:
  pipelinesascode.tekton.dev`; annotations add `sender`, `branch`,
  `source-branch`, `repo-url`, `sha-url`, `git-provider` (`gitea`). The
  `event-type` of a Gitea pull request is `pull_request`, of a push `push`.
  The name in `.tekton` becomes `generateName` (`pull-request-xxxxx`).
- **Matching:** `on-event` and `on-target-branch` are both needed unless
  `on-cel-expression` is used; a CEL expression overrides the other matching
  annotations; branch globs work (`[main, release-*]` matches
  `refs/heads/release-1.0`). Two PipelineRuns with the same name in `.tekton`
  stop every run for the event ("found multiple pipelinerun in .tekton with the
  same name"). `max-keep-runs` deletes the oldest finished runs with the same
  `original-prname` after a run succeeds.
- **Concurrency:** with `concurrency_limit`, the controller creates the runs
  as pending (`state` label `queued`) and the watcher starts them in
  alphabetical order of name. A pending PipelineRun has no `startTime` until it
  starts. `cancel-in-progress` cannot be combined with `concurrency_limit`.
- **Access control:** the owner, collaborators with write access, organization
  members and users in `OWNERS` (`approvers`, `reviewers`) on the default
  branch may run pipelines. Others need `/ok-to-test` from an allowed user.
  `/retest` reruns only failed runs; `/test <name>` and `/retest <name>` force one.
- **Gitea API traps (from the sibling courses' live runs):** POST to
  `/contents/<path>` on an existing file answers 422; use PUT with the file
  `sha`. PATCH on a hook ignores `config.secret`; delete and recreate the hook.
- **No fixed host ports.** Scripts and graders reach Gitea from the `tester`
  pod. Pages may tell the reader to run `kubectl -n gitea port-forward
  svc/gitea-http 3000:3000` to browse Gitea; links in Gitea then show the
  in-cluster host name.
- **Many environments start broken on purpose.** A lab seeds a fault (a
  duplicate Repository, a wrong webhook port, a misnamed Secret key, a wrong
  `on-event`, a CEL expression for the wrong branch, a mismatched webhook
  secret). The fault is the material. Never "fix" it in the bootstrap.

### Where things are in this repo

| What | Where |
| --- | --- |
| Course outline the platform reads: every reading page and lab, in order. Never list `solution.md` here | `astrona.yaml` |
| Overview, sections and modules tables, how to run things | `README.md` |
| Introduction (see "Every course starts with an Introduction") | `sections/intro/` |
| Section overview and its modules | `sections/section-0N0/README.md` |
| Module reading: landing page, deep-dive parts, closing page | `sections/section-0N0/module-0M/course.md`, `course-0N-*.md` |
| Graded lab: task, walkthrough, setup, grader | `.../labs/lab-01/` (`question.md`, `solution.md`, `prerequisites.md`, `bootstrap/`, `manifests/`, `solution/`, `testing/`, `validation/`) |
| Ungraded sandbox for a module | `.../playground/` (`config.yaml`, `bootstrap/prepare.sh`, `manifests/`, `docs/overview.md`, which is the only learner page) |
| One graded integration lab per section | `sections/section-0N0/capstone/labs/lab-01/` |

A lab folder holds:

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition; `metadata.docs` points at `question.md` and `solution.md` |
| `README.md` | Short intro for authors with `estimated_duration` front matter and the run, submit and destroy commands |
| `prerequisites.md` | What the learner needs before starting |
| `question.md` | The task. Starts with `# Question` and `Solve this question on: \`terminal\`` |
| `solution.md` | Step-by-step walkthrough |
| `bootstrap/01-install-tekton-pac.sh` | `tkn`, `tkn-pac`, Tekton Pipelines, Pipelines-as-Code (where the lab starts with it), Gitea users and the token Secret |
| `bootstrap/02-seed-state.sh` | The repository, its branches, the connection and the seeded faults |
| `manifests/` | `lab-start.yaml` (namespaces, Gitea, tester), `repo/` (files seeded into `main`), `branches/` (files for other branches), Repository YAML |
| `solution/apply.sh` | Reference end state, applied only by `astrona test`; it changes Git through the Gitea API |
| `testing/wait-for-environment.sh` | Waits until Tekton, Pipelines-as-Code and Gitea answer |
| `validation/validate-*.sh` | Behavioural grading, one script per check |

The bootstrap and seed scripts of all nine environments share their code.
They were generated from one template; when you change a helper, change it in
every copy.

### Lab metadata in `astrona.yaml`

`astrona.yaml` has a `training:` block (id `ATS128`, domain
`Pipelines-as-Code & Git-Native CI`, weight `15`) and one entry per section
under `modules:` (`module-010`, `module-020`, `module-030`). Each section's
`content` lists, in order: the section `README.md`, then for each module its
landing page, its parts, and right after the part a lab tests, a `Question`
reading (`labs/lab-01/question.md`) followed by the `type: lab` entry; the
module's closing page comes last. The section capstone closes the section.
Playgrounds are not listed.

Every `type: lab` entry carries the same fields, in the same order, as in
ATS016: `title`, `path`, `difficulty`, `estimated_duration`, `topic`,
`task_kind`, `tags`, `learning_goals`, `resources`.

- `difficulty`: `beginner`, `intermediate` or `advanced`.
- `estimated_duration`: realistic time to solve it, for example `15m`, `30m`.
- `topic`: exactly one of `installation`, `repository-connection`,
  `event-matching`, `concurrency`, `access-control`.
- `task_kind`: exactly one of `build`, `troubleshooting` or `migration`.
- `tags`: 4 to 8 ids, only from the tag list below. Add a new tag to the list
  first if nothing fits.
- `learning_goals`: 2 or 3 plain sentences, each starting with a verb.
- `resources`: 1 to 4 official pages (`tekton.dev` or `pipelinesascode.com`),
  each with a `name` and a `url` that loads. This is the **only** place
  outside links are allowed.

**Tag list** (lower case, hyphens, never synonyms):

- Installation: `pipelines-as-code`, `release-manifest`, `pac-controller`,
  `pac-watcher`, `pac-webhook`, `tkn-pac`
- Connection: `repository-crd`, `git-provider`, `gitea`, `webhook`,
  `webhook-secret`, `provider-token`
- Event matching: `tekton-directory`, `dynamic-variables`, `on-event`,
  `on-target-branch`, `on-cel-expression`, `max-keep-runs`, `pipelinerun`
- Status, concurrency, access: `commit-status`, `concurrency-limit`,
  `ok-to-test`, `owners-file`, `acl`, `fork-pull-request`

### Running things

```bash
# Playground (ungraded)
astrona run --git ssh://git@github.com/astrona-io/ATS128.git -c sections/section-010/module-01/playground
astrona destroy ats-128-playground-010-01   # takes metadata.name from config.yaml, not the path

# Lab or capstone (graded against the live cluster)
astrona run --git ssh://git@github.com/astrona-io/ATS128.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-128-lab-010-01

# Authors: run a local, uncommitted copy, and prove a lab passes with its reference solution
astrona run -c sections/section-010/module-01/playground
astrona test -c sections/section-010/module-01/labs/lab-01
```

Names: a playground is `ats-128-playground-<section>-<module>`, a module lab
is `ats-128-lab-<section>-<module>` and a capstone is
`ats-128-capstone-<section>`; keep those names. Lab bootstrap scripts do not
pin a kube context: astrona sets `KUBECONFIG` for the lab. Every lab must pass
`astrona validate` and `astrona test`.

Graders check **behaviour**, not just that an object exists: a PipelineRun
that Pipelines-as-Code created for the current head commit of a pull request,
with `Succeeded` `True`, the result `commit` equal to that SHA, and the
commit status `success` in Gitea. Several graders make their own Git commits
(to `main`, to `release-1.0`, to `feature-engines`, or as `cadet` to the fork)
to test matching, cleanup and trust. Graders also reject the plausible but
wrong fix: a hard-coded revision, a pull request retargeted to another branch,
a second Repository for the same URL, a webhook on the container port,
deleting one of the queued pipelines, or making `cadet` a collaborator instead
of listing them in `OWNERS`. A lab's `question.md` and `solution.md` must
match what its `validation/` scripts actually check.

Test clusters on the maintainer's machine: one at a time. Each environment
runs four Tekton Deployments, three Pipelines-as-Code Deployments (where
installed), Gitea and the tester pod. No script uses a fixed host port.

### Where to find trusted sources

Check facts here before writing them down. Prefer these over memory.

- **Pipelines-as-Code:** <https://pipelinesascode.com> and `docs/content/docs/`
  in `tektoncd/pipelines-as-code` at `v0.52.0`: `installation/kubernetes.md`,
  `providers/` (`github-app.md`, `github-webhook.md`, `forgejo.md`),
  `guides/repository-crd/`, `guides/creating-pipelines/`,
  `guides/event-matching/`, `guides/running-pipelines.md`,
  `guides/statuses.md`, `guides/gitops-commands/`, `advanced/concurrency.md`,
  `advanced/cleanup.md`, `api/configmap.md`, `api/repository-spec.md`, `cli/`.
- **Tekton Pipelines:** [PipelineRuns](https://tekton.dev/docs/pipelines/pipelineruns/),
  [Pipelines](https://tekton.dev/docs/pipelines/pipelines/).
- **Gitea API:** the Swagger page of the running Gitea (`/api/swagger`).
- **The landscape:** Tekton's page on the CNCF site,
  <https://www.cncf.io/projects/tekton/> (incubating, accepted 13 March 2026).

### Skills to use here

The `astrona-course-*` skills do most authoring jobs in this repository:
planning (`domain-plan`), creating the tree (`domain-scaffold`), building
modules (`domain-build`), deep-dive parts (`deep-dive`), labs and playgrounds
(`lab`), lab docs (`lab-docs`), challenges (`create-challenge`), quizzes
(`generate-assessment`) and fact-checking (`review-accuracy`).
