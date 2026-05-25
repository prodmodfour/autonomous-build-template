# Usage

## 1. Create a new project from this template

Use GitHub's template feature, or copy this repository manually.

## 2. Customise the project brief

Edit `PROJECT_BRIEF.md`.

Set:

```text
TEMPLATE_CUSTOMISED: true
```

Fill in:

* project name
* project type
* project goal
* audience
* success criteria
* non-goals
* technology preferences
* architecture expectations
* quality expectations
* documentation expectations
* safety constraints

## 3. Replace the tickets

Edit `BUILD_TICKETS.md`.

Keep the top-level line:

```text
AUTOMATION_STATUS: IN_PROGRESS
```

Then replace the example tickets with project-specific tickets.

Good tickets are:

* small
* ordered
* testable
* clear about expected files/behaviour
* clear about docs and validation
* scoped to one change

## 4. Preview script output formatting

Run the mock output demo to see the coloured, delineated section style without invoking an agent, validation, git, or network commands:

```bash
scripts/mock-output.sh
```

## 5. Choose or create a work branch

Run on the current branch, select an existing branch, or create a new branch before the loop starts.

Select an existing local branch, or a unique remote branch:

```bash
scripts/build-loop.sh --branch feature/autonomous-build --max-cycles 20
```

Create a branch from `HEAD`:

```bash
scripts/build-loop.sh --create-branch feature/autonomous-build --max-cycles 20
```

Create a branch from a specific start point:

```bash
scripts/build-loop.sh --create-branch feature/autonomous-build --branch-start main --max-cycles 20
```

`--branch` and `--create-branch` require a clean working tree and cannot be used together.

## 6. Optionally create a GitHub or GitLab repository

Use `scripts/create-remote-repo.sh` after authenticating the relevant CLI.

GitHub:

```bash
gh auth login
scripts/create-remote-repo.sh --github --name OWNER/REPO --visibility private --branch feature/autonomous-build
```

GitLab:

```bash
glab auth login
scripts/create-remote-repo.sh --gitlab --name GROUP/REPO --visibility private --branch feature/autonomous-build
```

The helper requires a clean working tree for real runs. It creates the remote repository, adds the selected local remote name (`origin` by default), and pushes the current branch by default. Use `--no-push` to create only the remote repository.

If `origin` already points somewhere else, either choose another remote name:

```bash
scripts/create-remote-repo.sh --github --name OWNER/REPO --remote project-origin
```

or intentionally replace it:

```bash
scripts/create-remote-repo.sh --github --name OWNER/REPO --replace-remote
```

Preview without network or git changes:

```bash
scripts/create-remote-repo.sh --gitlab --name GROUP/REPO --dry-run --no-push
```

## 7. Run one cycle

```bash
scripts/build-loop.sh
```

## 8. Run multiple autonomous cycles

```bash
scripts/build-loop.sh --max-cycles 20
```

At the start of each cycle, the loop prints the current ticket it is working on.
The loop pushes each successful cycle's commit by default.

## 9. Create and merge PRs/MRs as the loop progresses

Use `--pr-each-cycle` to create a GitHub pull request or GitLab merge request after a successful cycle commit. If an open PR/MR already exists for the work branch, later cycles reuse it and push more commits to it:

```bash
scripts/build-loop.sh --branch feature/autonomous-build --pr-each-cycle --pr-base main --max-cycles 20
```

Use `--merge-pr-each-cycle` to create and immediately merge each PR/MR:

```bash
scripts/build-loop.sh --branch feature/autonomous-build --merge-pr-each-cycle --pr-base main --max-cycles 20
```

PR/MR automation requires:

* pushing enabled; do not combine it with `--no-push`
* a configured remote, `origin` by default or `--pr-remote NAME`
* an authenticated GitHub CLI (`gh`) or GitLab CLI (`glab`)
* a work branch that is different from the base/target branch

The provider is auto-detected from the remote URL when possible. Otherwise pass `--pr-provider github` or `--pr-provider gitlab`. The base branch is detected from the remote default branch when possible. Otherwise pass `--pr-base main`, `--pr-base master`, or another target branch.

The merge mode asks the platform CLI for a normal merge and keeps the source branch so the next autonomous cycle can continue on it. Branch protection, required checks, merge conflicts, repository merge-strategy settings, or missing permissions can still stop the loop.

## 10. Run without pushing

```bash
scripts/build-loop.sh --max-cycles 20 --no-push
```

The legacy `--push` flag is still accepted, but pushing is already enabled by default.

## 11. Build-loop logs and lock files

Active build-loop state is kept outside the repository by default:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/autonomous-build-template/build-loop/<repo-key>/
```

This directory contains cycle logs and the active lock directory. Keeping it outside `.agent/` prevents private/runtime cleanup from deleting the parent directory needed by `tee` between cycles.

Override the per-repository state directory when needed:

```bash
AUTONOMOUS_BUILD_LOOP_STATE_DIR=/path/to/build-loop-state scripts/build-loop.sh --max-cycles 20
```

## 12. Automatic agent failure recovery

If an implementation run fails with a token or context-length error, the loop asks the configured Pi agent wrapper to split the current lowest-numbered `TODO` or `IN_PROGRESS` ticket into two smaller tickets. The split is committed, and the same cycle is retried so `--max-cycles 1` can still complete one implementation cycle after recovery.

If an implementation run fails for another reason, the loop assumes a transient provider/server issue and retries the same cycle after 10 minutes.

Override the retry delay when needed:

```bash
AUTONOMOUS_BUILD_RETRY_SECONDS=60 scripts/build-loop.sh --max-cycles 20
```

Use `AUTONOMOUS_BUILD_RETRY_SECONDS=0` for immediate retries in tests.

## 13. If branch is already ahead

Branches that are already ahead of upstream are allowed by default. The loop still refuses to start when the branch is behind upstream, and still stops if upstream advances during a cycle.

The legacy `--allow-ahead` flag is still accepted for older scripts, but it is no longer required.

## 14. Changing the agent

The main build loop is agent-agnostic.

To change the agent command, edit:

```text
scripts/run-agent.sh
```

The default wrapper uses:

```bash
pi --no-session -p @AGENTS.md @PROJECT_BRIEF.md @BUILD_TICKETS.md @BUILD_NOTES.md "$PROMPT"
```

It intentionally does not pass model or thinking-level flags.

## 15. Completion

The final ticket should set the top-level status in `BUILD_TICKETS.md` to:

```text
AUTOMATION_STATUS: DONE
```

The build loop checks only the first top-level status line.
