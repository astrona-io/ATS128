# Summary

The provider decides how the controller hears about an event and how it proves who it is when it answers. The rest of Pipelines-as-Code, the templates, the matching and the commands, stays the same.

## What you learned

A GitHub App has its own identity. The controller reads the App ID, the private key and the webhook secret from one Secret in its own namespace, creates a short-lived installation token for each event and reports with the Checks API. The `Repository` then needs only the URL.

Without an App, a GitHub repository uses a personal access token and a repository webhook, stored in a Secret that the `Repository` names under `git_provider`. That brings one token and one webhook for each repository, and results appear as commit statuses.

GitLab uses a token with the `api` scope and a project webhook that carries a secret token. Its merge requests map to the event `pull_request`. Bitbucket Cloud uses a user and an app password and checks the source address of the webhook because it has no shared secret. Bitbucket Data Center uses an access token, a server address and a webhook secret. The key facts to remember are these:

- A `Repository` for a GitHub App has no `git_provider` block.
- `git_provider.url` is the base address of a self-managed server and never includes the project path.
- Bitbucket Cloud needs `git_provider.user`.
- A server dry run proves that the object is valid, not that the credentials work.

<!-- astrona:playground:destroy -->
