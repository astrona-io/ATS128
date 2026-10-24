# Welcome To The Course

This course trains you for the **Pipelines-as-Code & Git-Native CI** part of the Astrona **Tekton** training path. That part is 15% of the path. This page tells you who the course is for, what you can do at the end, which words and example setup it uses, and how its pages fit together.

## Who this course is for

You know your way around Kubernetes: namespaces, pods, Secrets, Services, `kubectl apply`, `kubectl get` and `kubectl logs`. You know Git: branches, commits and pull requests. You have seen a Tekton `Task`, a `Pipeline` and a `PipelineRun` before, even if you do not remember every field. You do not need to know Pipelines-as-Code yet. Each new idea is explained the first time it appears.

## What you can do at the end

Continuous integration (CI) means that every change to the code is built and tested automatically. With Pipelines-as-Code, the pipeline that does this lives in the Git repository next to the code, and a Git event, such as a new pull request, starts it. This course does not ask you to remember words. It asks you to connect a repository, write the pipelines, and find out why a pull request did not start a run. The course has three topics, and each one turns into a set of skills you will practise.

The first topic is **Pipelines-as-Code and its installation**. You will learn to:

- Explain how a Git event becomes a PipelineRun, and which component does each step.
- Explain the difference between a GitHub App, a GitHub webhook and the other Git providers.
- Install Pipelines-as-Code and the `tkn pac` plugin, and connect a repository with a token and a webhook.

The second topic is **the `.tekton` directory and event matching**. You will learn to:

- Write PipelineRuns in the `.tekton` folder with dynamic variables such as `{{ revision }}`.
- Choose the events and branches that start each PipelineRun, with annotations and CEL expressions.
- Keep the number of old runs under control with `max-keep-runs`.

The third topic is **status, concurrency and access control**. You will learn to:

- Read the result that Pipelines-as-Code reports back to the pull request.
- Queue runs with `concurrency_limit`.
- Decide who may run pipelines, with the `OWNERS` file, `/ok-to-test` and `/retest`.

Everything is written for **Pipelines-as-Code v0.52.0**, **Tekton Pipelines v1.17.1** and **tkn v0.46.2**.

## The words this course uses

The pages use the project's and Kubernetes' own terms, because those are the words you meet in the product, the logs and the documentation. Each term gets a short, plain definition the first time it appears on a page. A few terms come back on almost every page, so here they are up front.

| Term | What it is |
| --- | --- |
| Pipelines-as-Code | A Tekton project that runs the PipelineRuns stored in a repository's `.tekton` folder when Git events happen |
| `Repository` | A Kubernetes object that connects one Git repository to one namespace |
| Webhook | An HTTP request the Git server sends to Pipelines-as-Code when something happens, such as a new pull request |
| Commit status | A short result (`pending`, `success`, `failure`) that Pipelines-as-Code attaches to a commit in the Git server |
| Dynamic variable | A placeholder such as `{{ revision }}` that Pipelines-as-Code fills in before it starts the run |

## The example setup in your playground

The domain is about GitHub, but a lab on your laptop cannot create a GitHub App or receive webhooks from the internet. So every playground and lab runs its own Git server, **Gitea**, inside the cluster. Pipelines-as-Code supports Gitea as a Git provider, and the pages explain the GitHub way next to it wherever the two differ.

The Gitea user `starfleet` owns the repository `starfleet/bridge-app`, a tiny application with a `.tekton` folder. The `Repository` object and every PipelineRun live in the Kubernetes namespace `starfleet`. A small `tester` pod in the namespace `gitea` lets you call the Gitea API with `curl`, so you can open pull requests and push commits without a browser. The passwords in these examples are for the lab only.

Many labs start with something broken on purpose: a webhook that points at the wrong port, a PipelineRun that never matches, a secret that does not match. That is the material, not a fault in the course.

## How the course is laid out

The course has three sections. It starts with the installation and the connection, goes on to the pipelines in the `.tekton` folder, and ends with what happens around a run: the status, the queue and the permissions.

| Section | What it covers |
| --- | --- |
| 010 | Install Pipelines-as-Code And Connect A Repository |
| 020 | The .tekton Directory And Event Matching |
| 030 | Pull Request Status, Concurrency And Access Control |

Each section has one or more **modules**, and each module teaches one skill. A module brings together four kinds of material:

| What | What it is for | Graded? |
| --- | --- | --- |
| **Reading** | A short landing page, a few chapters that teach one idea each, and a summary | No |
| **Playground** | A small cluster on your own machine, to try everything you read | No |
| **Lab** | A cluster in a starting state, a task, and a grader that checks your work | Yes |
| **Capstone** | The last lab in a section, with several faults at once | Yes |

The best order is simple: read the chapters with the playground open next to them, take each lab when a chapter sends you to it, and finish each section with its capstone. The next part of this page explains how a module's pages guide you through that order.

## How to read a page

A module starts with a **landing page**. It says what the module teaches, what you should know first, and the order of its chapters. At the bottom of the landing page you start the module's playground, and you keep it running while you read.

The chapters (the parts of a module) read like the chapters of a technical book. Each one opens with the problem it solves, explains one idea in connected paragraphs, and closes with what you now know. The hands-on steps sit right in the text: a sentence or two on what to run and why, the command, and then what the result shows. Run each step in your playground as you reach it.

Every chapter ends with a box of common pitfalls, the mistakes people make most often with what the chapter taught, and how to spot them. Now and then a page also has a tip box with a habit or shortcut you can use again, well beyond that page. The two boxes look like this:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every chapter ends with one.

When a graded lab tests what a chapter taught, that chapter ends with a **Your mission** section. It tells you what the lab asks, then gives every command you need, in order: pause the playground with `astrona stop`, start the lab with `astrona run`, and send your work for grading with `astrona submit`. Solve the lab on your own before you look at its solution. When the lab is done, remove it with `astrona destroy` and start the playground again with `astrona start`.

The last page of every module is the **Summary**. It sums up what you learned in a few short paragraphs, organised by idea. It also ends the module's hands-on work: the Summary page removes the playground, so your machine is clean before the next module.

One rule holds on every page. Code blocks are exactly what you type. Never change a command to make it "look right". If the result is different from what the page describes, that difference is the lesson.
