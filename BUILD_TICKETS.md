# BUILD_TICKETS.md

AUTOMATION_STATUS: IN_PROGRESS

Ticket statuses:

* TODO
* IN_PROGRESS
* DONE
* BLOCKED

The build loop must select the lowest-numbered TODO or IN_PROGRESS ticket.

Replace these example tickets with project-specific tickets before running the build loop.

---

## 000 — Bootstrap project skeleton

Status: TODO

Create the initial project structure based on `PROJECT_BRIEF.md`.

Required:

* README.md updated for the actual project
* appropriate source directories
* appropriate test/validation directories
* appropriate documentation structure
* project-specific quality gate support
* `.gitignore` updated for the project stack

Run `scripts/quality-gate.sh`.

Update `BUILD_TICKETS.md` and `BUILD_NOTES.md`.

Commit when complete.

---

## 001 — Add core project functionality

Status: TODO

Implement the first core feature described in `PROJECT_BRIEF.md`.

Required:

* keep scope narrow
* add tests or validation
* update docs if behaviour/setup changes
* run quality gate

Commit when complete.

---

## 002 — Add secondary functionality or integration

Status: TODO

Implement the next core feature or integration described in `PROJECT_BRIEF.md`.

Required:

* keep scope narrow
* add tests or validation
* update docs if behaviour/setup changes
* run quality gate

Commit when complete.

---

## 003 — Add documentation and operational polish

Status: TODO

Improve project documentation.

Include whichever are relevant:

* architecture
* local development
* usage
* operations
* deployment
* security
* limitations
* troubleshooting

Run `scripts/quality-gate.sh`.

Commit when complete.

---

## 099 — Final autonomous review and completion marker

Status: TODO

Perform a final repository review.

Check:

* project brief goals are met
* tickets are complete
* docs match implementation
* quality gates pass
* no secrets/private data are committed
* generated/private files are not committed
* repository is clear for its intended audience

Run full quality gate.

If everything is complete, set the top-level automation status to:

AUTOMATION_STATUS: DONE

Commit final review.

---
