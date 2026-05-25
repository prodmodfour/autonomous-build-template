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

Added optional PR/MR automation to the build loop:

* added `--pr-each-cycle` / `--create-pr` to create or reuse a PR/MR after each successful cycle
* added `--merge-pr-each-cycle` / `--merge-pr` to create and merge as the loop progresses
* supports GitHub via `gh` and GitLab via `glab`
* added shared PR/MR helper functions and a regression test with a fake `gh` CLI
* documented setup requirements and usage in README and usage docs

## Known blockers

None.

## Next recommended ticket

Customise the project brief and build tickets before running the autonomous loop.
