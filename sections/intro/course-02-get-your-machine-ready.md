# Get Your Machine Ready

Every playground and lab in this course runs on your own machine, in a small Kubernetes cluster. A tool called `astrona` builds it for you, sets it up, grades your work and removes it again. This page gets your machine ready: first the tools you need, then the handful of `astrona` commands you will use every day, and last what to do when a start goes wrong.

## What you need

Every section needs the same set of tools. Install these before you start:

- **A container engine:** Docker or Podman. The cluster runs inside it.
- **`kind`:** runs Kubernetes inside the container engine. Pipelines-as-Code v0.52.0 needs Kubernetes 1.28 or later; any recent `kind` release is fine.
- **`kubectl`:** talks to the cluster.
- **`tkn` and `tkn pac`:** the Tekton command-line tool and its Pipelines-as-Code plugin. Each playground and lab installs `tkn` 0.46.2 and `tkn-pac` 0.52.0 for you, so the versions always match the course.
- **The astrona command-line tool.**
- **A web browser**, if you want to look at the Gitea pages of your repository.

The playgrounds and labs also need **outbound internet** while they start. They download `tkn` and `tkn-pac` from GitHub, the Tekton release manifest from `infra.tekton.dev`, the Pipelines-as-Code release manifest from GitHub, and the Tekton and Pipelines-as-Code images from `ghcr.io` and `cgr.dev`. Without outbound internet, those starts fail with errors that have nothing to do with Tekton.

You do not have to check your tools by hand. Let `astrona` look at your machine for you:

```sh
astrona setup
```

`astrona setup` looks at what is missing, shows you each step it would take, and asks before it does anything. On macOS it can install `kind`, `kubectl` and Podman.

Later, you can check your machine at any time:

```sh
astrona check
```

## The commands you use every day

Once your machine is ready, you need only a handful of `astrona` commands. Each module page and lab page shows the exact command to copy, so you do not need to remember paths. This section walks through them in the order you meet them: sign in, start, pause, submit and clean up.

Labs from the course catalog are tied to your Astrona account, so you sign in first:

```sh
astrona login
```

Next you start a playground or a lab. Each module page and lab page shows the exact `astrona run` command for it. It looks like this:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS128.git -c sections/section-010/module-01/playground
```

When the cluster is ready, `kubectl`, `tkn` and `tkn pac` already point at it.

A chapter that sends you to a lab asks you to pause the playground first. Pausing frees your machine's memory but keeps everything you built:

```sh
astrona stop <name>
```

When the lab is done, start the playground again and carry on where you left off:

```sh
astrona start <name>
```

Inside a lab, you send your work for grading with `astrona submit`. The grader checks the live cluster and the Git server. It reads your objects, and some graders push commits of their own to see whether the right pipelines start, so your fix has to actually work. Each lab page shows the exact command:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

You can submit as often as you like.

When you are done with a playground or a lab, remove it:

```sh
astrona destroy <name>
```

The name is the environment's name, printed by `astrona run` and shown on each page (for example `ats-128-playground-010-01`). It is not the folder path. To see what is on your machine, list it:

```sh
astrona list
```

> [!WARNING]
> **Run one environment at a time.** Each playground and lab is a whole cluster with Tekton, Pipelines-as-Code and a Git server. Two running at once can use up your machine's memory, and it is easy to send a command to the wrong one. Pause or destroy the playground before you start the lab.

## When a start goes wrong

Sometimes a playground or lab does not start cleanly. Ask `astrona` what is wrong before you try anything else:

```sh
astrona doctor
```

It checks your machine, the lab's configuration and the running lab, and tells you how to fix what it finds.

If a start fails while it downloads something, check your network first. If `kubectl apply` refuses a Tekton or `Repository` object right after a start, with an error that mentions a webhook, an admission webhook is still starting: wait a few seconds and apply again. Remember also that a lab whose pull request never got tested is often broken on purpose: the lab's task tells you when that is the case. With your machine ready and these commands at hand, you can start the first module.
