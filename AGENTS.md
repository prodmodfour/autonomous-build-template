# AGENTS.md

You are working in an autonomous, ticket-driven build system.

This file contains general rules. Project-specific instructions live in `PROJECT_BRIEF.md`.

## Required reading

Before making changes, read:

* `AGENTS.md`
* `PROJECT_BRIEF.md`
* `BUILD_TICKETS.md`
* `BUILD_NOTES.md`

## Core workflow

When invoked by the build loop:

1. Select the lowest-numbered `TODO` or `IN_PROGRESS` ticket from `BUILD_TICKETS.md`.
2. Implement only that ticket.
3. Do not start future tickets.
4. Do not broaden scope.
5. Add or update tests/validation where appropriate.
6. Add or update docs where appropriate.
7. Run `scripts/quality-gate.sh`.
8. Update `BUILD_TICKETS.md`.
9. Update `BUILD_NOTES.md`.
10. Commit the completed ticket with a conventional commit message.
11. Leave the working tree clean.

## If blocked

If you cannot complete the ticket safely:

* explain the blocker in `BUILD_NOTES.md`
* mark the ticket `BLOCKED` if appropriate
* do not mark it `DONE`
* do not commit broken partial work
* leave the working tree clean if possible

## Scope control

Do not:

* start future tickets
* silently change project goals
* rewrite unrelated code
* add unnecessary dependencies
* add speculative features
* remove safety checks
* bypass quality gates
* commit generated/private files unless explicitly required

## Safety rules

Never commit:

* real secrets
* credentials
* access tokens
* private keys
* real `.env` files
* private data
* internal hostnames
* internal URLs
* employer/client data
* Terraform state
* generated cloud plans
* machine-specific configuration

Do not add destructive automation unless the project brief explicitly allows it and the ticket specifically asks for it.

Do not implement arbitrary code execution, shell execution, or unsafe command execution unless the project is explicitly about that and the safety model is clearly documented.

## Documentation rules

Update docs when behaviour, setup, architecture, operations, security, limitations, or public-facing usage changes.

Prefer clear, honest limitations over pretending the project is production-ready.

## Testing and validation

Use the project’s quality gates.

If a project-specific gate does not exist yet, improve `scripts/quality-gate.sh` or document why the gate is not applicable.

## Commit style

Use conventional commits:

```text
chore:
feat:
fix:
test:
docs:
refactor:
ci:
build:
```

Examples:

```text
chore: bootstrap project skeleton
feat: add user registration endpoint
test: cover tenant isolation
docs: add deployment guide
ci: add validation workflow
fix: align health check path
```

## Completion

A project is complete only when:

* the final ticket is done
* quality gates pass
* docs match implementation
* safety constraints are respected
* the top-level `AUTOMATION_STATUS` in `BUILD_TICKETS.md` is set to `DONE`
