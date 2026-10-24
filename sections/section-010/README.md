# Section 010: Install Pipelines-as-Code And Connect A Repository

Continuous integration (CI) means that every change to the code is built and tested automatically. Tekton can run the pipelines for CI, but on its own it does not know when to start them. Pipelines-as-Code closes that gap: it keeps the pipelines in the Git repository, starts them when a Git event happens, and reports the result back to the pull request. This section installs it and connects the first repository.

You first learn the model: the `.tekton` folder, the path from a webhook to a PipelineRun, the three components (controller, watcher, admission webhook), the `Repository` object, and the difference between a GitHub App, a GitHub webhook and the other Git providers. Then you install Pipelines-as-Code from its release manifest and look at what it created. Last, you connect a Gitea repository with a token, a webhook secret and a webhook, and follow a pull request to a green commit status.

**Topic covered:** Concepts and installation

## What you will learn

- The Pipelines-as-Code model: PipelineRun templates in `.tekton`, started by Git events, results reported to the Git provider.
- What the pipelines-as-code-controller, the pipelines-as-code-watcher and the pipelines-as-code-webhook do.
- The `Repository` object, and why only one may exist for a repository URL.
- GitHub App versus GitHub webhook versus GitLab, Bitbucket, Forgejo and Gitea, and why the labs use Gitea.
- Installing Pipelines-as-Code v0.52.0 from `release.k8s.yaml` and checking it with `kubectl` and `tkn pac`.
- Connecting a repository: the Secret, the `Repository`, the webhook on the Service port 8080, and the commit status that comes back.

## The learning path

The section has one module. It has a landing page, three short parts, a graded lab right after the part it tests, and a summary. The module also has its own playground, a cluster where you can explore freely, and the landing page starts it for you.

### 1. Connect A Git Repository To Pipelines-as-Code

The module starts at its landing page, which also launches the playground. The playground runs Tekton Pipelines v1.17.1, a Gitea server with the repository `starfleet/bridge-app`, and the `tkn` and `tkn pac` tools. Pipelines-as-Code is not installed yet; you install it in the second part.

1. What Pipelines-as-Code Is And How Events Become Runs
2. Install Pipelines-as-Code And The tkn pac Plugin
3. Connect A Repository With A Token And A Webhook, followed by the lab **Connect A Gitea Repository To Pipelines-as-Code**
4. Summary

## Section capstone: Repair A Broken Repository Connection

The capstone is one graded scenario that combines the whole module. Pipelines-as-Code runs and a pull request is open on `starfleet/bridge-app`, but nothing ever tested it. An old `Repository` for the same URL sits in the wrong namespace, the Secret stores the token under a key the `Repository` does not read, and the Gitea webhook targets the wrong port. Find each fault, fix it, and prove the repair with a PipelineRun in `starfleet` and a green commit status. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS128.git -c sections/section-010/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-128-capstone-010
```
