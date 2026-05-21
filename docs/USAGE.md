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

## 9. Run without pushing

```bash
scripts/build-loop.sh --max-cycles 20 --no-push
```

The legacy `--push` flag is still accepted, but pushing is already enabled by default.

## 10. If branch is already ahead

By default, the loop refuses to start if the branch is ahead of upstream.

To allow this:

```bash
scripts/build-loop.sh --max-cycles 20 --allow-ahead
```

## 11. Changing the agent

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

## 12. Completion

The final ticket should set the top-level status in `BUILD_TICKETS.md` to:

```text
AUTOMATION_STATUS: DONE
```

The build loop checks only the first top-level status line.
