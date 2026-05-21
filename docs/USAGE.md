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

## 5. Run one cycle

```bash
scripts/build-loop.sh
```

## 6. Run multiple autonomous cycles

```bash
scripts/build-loop.sh --max-cycles 20
```

At the start of each cycle, the loop prints the current ticket it is working on.
The loop pushes each successful cycle's commit by default.

## 7. Run without pushing

```bash
scripts/build-loop.sh --max-cycles 20 --no-push
```

The legacy `--push` flag is still accepted, but pushing is already enabled by default.

## 8. If branch is already ahead

By default, the loop refuses to start if the branch is ahead of upstream.

To allow this:

```bash
scripts/build-loop.sh --max-cycles 20 --allow-ahead
```

## 9. Changing the agent

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

## 10. Completion

The final ticket should set the top-level status in `BUILD_TICKETS.md` to:

```text
AUTOMATION_STATUS: DONE
```

The build loop checks only the first top-level status line.
