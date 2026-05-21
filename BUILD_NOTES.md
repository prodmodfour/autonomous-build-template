# BUILD_NOTES.md

## Current state

Template repository state.

Before running the build loop for a real project:

1. Edit `PROJECT_BRIEF.md`.
2. Set `TEMPLATE_CUSTOMISED: true`.
3. Replace the example tickets in `BUILD_TICKETS.md`.

The build loop now keeps active logs and lock files outside the repository by default, under `${XDG_STATE_HOME:-$HOME/.local/state}/autonomous-build-template/build-loop/<repo-key>/`. Set `AUTONOMOUS_BUILD_LOOP_STATE_DIR` to override the per-repository state directory.

## Quality gates

Latest run:

```bash
bash scripts/quality-gate.sh
```

Result: passed.

## Latest cycle notes

Fixed build-loop runtime state handling in the template:

* moved active log and lock paths out of `.agent/` by default
* added the `AUTONOMOUS_BUILD_LOOP_STATE_DIR` override
* recreated the log directory before each `tee`
* added a regression test that simulates `.agent/` cleanup between cycles
* documented the external state directory in README and usage docs

## Known blockers

None.

## Next recommended ticket

Customise the project brief and build tickets before running the autonomous loop.
