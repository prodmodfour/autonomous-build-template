# Autonomous Build Template

A reusable template for running autonomous, ticket-driven software builds with an AI coding agent.

This template is intentionally project-agnostic. It can be used for:

- backend services
- frontend applications
- full-stack applications
- infrastructure-as-code projects
- CLI tools
- libraries and packages
- data projects
- documentation projects
- portfolio projects
- internal tools
- experiments

The template provides:

- a project brief
- ordered build tickets
- running build notes
- general agent rules
- an autonomous build loop
- a generic quality gate
- an agent wrapper script
- branch selection/creation support for autonomous runs
- GitHub/GitLab repository creation helper
- safety checks around dirty working trees, remote changes, and completion status

## Core idea

The agent works one ticket at a time.

Each autonomous cycle should:

1. Read `AGENTS.md`, `PROJECT_BRIEF.md`, `BUILD_TICKETS.md`, and `BUILD_NOTES.md`.
2. Select the lowest-numbered `TODO` or `IN_PROGRESS` ticket.
3. Print what it is working on now.
4. Implement only that ticket.
5. Run `scripts/quality-gate.sh`.
6. Update tickets and notes.
7. Commit the completed work.
8. Leave the working tree clean.

## Important

This template does **not** enforce a model or thinking level.

The build loop calls:

```bash
scripts/run-agent.sh "$PROMPT"
```

If you use Pi, keep the default wrapper.

If you use another agent later, edit only:

```text
scripts/run-agent.sh
```

## Repository files

```text
AGENTS.md              General rules for the coding agent
PROJECT_BRIEF.md       Project-specific brief; customise before running
BUILD_TICKETS.md       Ordered autonomous work queue
BUILD_NOTES.md         Build state, latest notes, blockers
CONTRIBUTING.md        Contribution guidelines
LICENSE.md             MIT license
SECURITY.md            Security reporting policy
scripts/build-loop.sh           Main autonomous loop
scripts/create-remote-repo.sh   GitHub/GitLab repository creation helper
scripts/run-agent.sh            Agent-specific wrapper
scripts/quality-gate.sh         Generic stack-aware validation script
scripts/test-build-loop-state.sh Regression test for external build-loop state
scripts/mock-output.sh          Mock output demo for terminal formatting
scripts/lib/pretty-print.sh     Shared formatting helpers for script output
scripts/lib/git-branch.sh       Shared branch selection/creation helpers
docs/USAGE.md                   How to use this template
```

## Using this template

After creating a new repo from this template:

1. Edit `PROJECT_BRIEF.md`.
2. Set `TEMPLATE_CUSTOMISED: true`.
3. Replace the example tickets in `BUILD_TICKETS.md`.
4. Optionally choose a work branch with `--branch` or `--create-branch`.
5. Optionally create a GitHub/GitLab repository with `scripts/create-remote-repo.sh`.
6. Run the build loop.

```bash
scripts/build-loop.sh --max-cycles 40
# or run on a new branch:
scripts/build-loop.sh --create-branch feature/autonomous-build --max-cycles 40
```

## Safety defaults

The build loop refuses to start if:

* the working tree is dirty
* required files are missing
* `PROJECT_BRIEF.md` is still marked as uncustomised
* the branch is behind upstream

Branches that are already ahead of upstream are allowed by default.

Use `--branch NAME` to select an existing local or unique remote branch before running, or `--create-branch NAME` to create one.

By default, the loop pushes after each successful cycle that creates a commit. Pass `--no-push` to keep commits local.

Build-loop logs and lock files are kept outside the repository by default:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/autonomous-build-template/build-loop/<repo-key>/
```

Set `AUTONOMOUS_BUILD_LOOP_STATE_DIR=/path/to/state` to override this per-repository state directory. Keeping active logs and locks out of `.agent/` prevents private/runtime cleanup from breaking later cycles.

The loop stops if:

* the agent fails
* the agent leaves a dirty working tree
* no new commit was created
* upstream changes during the cycle
* `AUTOMATION_STATUS: DONE` is set at the top level of `BUILD_TICKETS.md`

## Quick start

Create a new repo from this template, then:

```bash
git status
```

Edit:

```text
PROJECT_BRIEF.md
BUILD_TICKETS.md
```

Set:

```text
TEMPLATE_CUSTOMISED: true
```

Optionally run the loop on a work branch and create a remote repository with one provider:

```bash
scripts/build-loop.sh --create-branch feature/autonomous-build --max-cycles 1
scripts/create-remote-repo.sh --github --name OWNER/REPO --visibility private --branch feature/autonomous-build
# or:
scripts/create-remote-repo.sh --gitlab --name GROUP/REPO --visibility private --branch feature/autonomous-build
```

Run one cycle:

```bash
scripts/build-loop.sh
```

Run many cycles. Each successful cycle is pushed by default:

```bash
scripts/build-loop.sh --max-cycles 40
```

Run without pushing:

```bash
scripts/build-loop.sh --max-cycles 40 --no-push
```

## Template status

This repository is a template. New projects should customise the brief and tickets before running the autonomous loop.

## Contributing, security, and license

See `CONTRIBUTING.md` for contribution guidance, `SECURITY.md` for vulnerability reporting, and `LICENSE.md` for the MIT license.
