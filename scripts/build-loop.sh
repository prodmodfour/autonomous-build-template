#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build-loop.sh [options]

Runs autonomous build cycles.

Each cycle:

* reads AGENTS.md, PROJECT_BRIEF.md, BUILD_TICKETS.md, and BUILD_NOTES.md
* selects the lowest-numbered TODO/IN_PROGRESS ticket
* implements only that ticket
* runs quality gates
* updates BUILD_NOTES.md and BUILD_TICKETS.md
* commits the completed work
* leaves the working tree clean

Options:
--max-cycles N      Number of cycles to run. Default: 1.
--sleep SECONDS     Pause between successful cycles. Default: 0.
--push              Push after each successful cycle.
--allow-ahead       Allow starting when branch is already ahead of upstream.
--allow-template    Allow running even if PROJECT_BRIEF.md is still marked uncustomised.
-h, --help          Show this help.

This script intentionally does not pass a model or thinking level.
Agent invocation is delegated to scripts/run-agent.sh.
USAGE
}

MAX_CYCLES=1
SLEEP_SECONDS=0
PUSH_AFTER=0
ALLOW_AHEAD=0
ALLOW_TEMPLATE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --max-cycles)
      if [[ $# -lt 2 ]]; then
        echo "--max-cycles requires a value" >&2
        usage >&2
        exit 2
      fi
      MAX_CYCLES="$2"
      shift 2
      ;;
    --sleep)
      if [[ $# -lt 2 ]]; then
        echo "--sleep requires a value" >&2
        usage >&2
        exit 2
      fi
      SLEEP_SECONDS="$2"
      shift 2
      ;;
    --push)
      PUSH_AFTER=1
      shift
      ;;
    --allow-ahead)
      ALLOW_AHEAD=1
      shift
      ;;
    --allow-template)
      ALLOW_TEMPLATE=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! [[ "$MAX_CYCLES" =~ ^[0-9]+$ ]] || [[ "$MAX_CYCLES" -lt 1 ]]; then
  echo "--max-cycles must be a positive integer" >&2
  exit 2
fi

if ! [[ "$SLEEP_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "--sleep must be a non-negative integer" >&2
  exit 2
fi

REQUIRED_FILES=(
  AGENTS.md
  PROJECT_BRIEF.md
  BUILD_TICKETS.md
  BUILD_NOTES.md
  scripts/quality-gate.sh
  scripts/run-agent.sh
)

LOG_DIR=".agent/logs/build-loop"
LOCK_DIR=".agent/build-loop.lock"
CYCLE_UPSTREAM_REF=""
CYCLE_UPSTREAM_HEAD=""

PROMPT=$(cat <<'PROMPT_EOF'
You are continuing an autonomous ticket-driven build.

Read AGENTS.md, PROJECT_BRIEF.md, BUILD_TICKETS.md, and BUILD_NOTES.md.

Your task in this run:

* Select the lowest-numbered TODO or IN_PROGRESS ticket from BUILD_TICKETS.md.
* Implement only that ticket.
* Do not start future tickets.
* Do not broaden scope.
* Respect all project-specific instructions in PROJECT_BRIEF.md.
* Respect all general instructions in AGENTS.md.
* Add or update tests/validation where appropriate.
* Update documentation if the ticket changes setup, architecture, behaviour, operations, security posture, limitations, or public-facing usage.
* Run scripts/quality-gate.sh.
* Update BUILD_TICKETS.md with ticket status.
* Update BUILD_NOTES.md with:

  * what changed
  * quality gates run
  * any limitations
  * blockers, if any
  * next recommended ticket
* Commit the completed ticket with a conventional commit message.
* Leave the working tree clean.

If you cannot safely complete the ticket:

* explain the blocker in BUILD_NOTES.md
* mark the ticket BLOCKED if appropriate
* do not mark it DONE
* do not commit partial broken work
* leave the working tree clean if possible
PROMPT_EOF
)

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 127
  fi
}

require_clean_tree() {
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree is dirty; refusing to start." >&2
    git status --short >&2
    exit 1
  fi
}

require_customised_template() {
  if (( ALLOW_TEMPLATE == 1 )); then
    return 0
  fi

  if grep -Eq '^TEMPLATE_CUSTOMISED:[[:space:]]*false[[:space:]]*$' PROJECT_BRIEF.md; then
    echo "PROJECT_BRIEF.md is still marked TEMPLATE_CUSTOMISED: false." >&2
    echo "Edit PROJECT_BRIEF.md for this project and set TEMPLATE_CUSTOMISED: true before running." >&2
    exit 1
  fi
}

get_upstream_ref() {
  git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true
}

get_automation_status() {
  awk -F: '
    /^##[[:space:]]/ { exit }
    /^AUTOMATION_STATUS:/ {
      status=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
      print status
      exit
    }
  ' BUILD_TICKETS.md
}

sync_before_cycle() {
  local upstream_ref
  local counts
  local behind_count
  local ahead_count

  require_clean_tree

  upstream_ref="$(get_upstream_ref)"
  CYCLE_UPSTREAM_REF="$upstream_ref"
  CYCLE_UPSTREAM_HEAD=""

  if [[ -z "$upstream_ref" ]]; then
    echo "No upstream configured; skipping remote sync checks."
    return 0
  fi

  git fetch --quiet
  CYCLE_UPSTREAM_HEAD="$(git rev-parse "$upstream_ref")"
  counts="$(git rev-list --left-right --count "${upstream_ref}...HEAD")"
  read -r behind_count ahead_count <<< "$counts"

  if (( behind_count > 0 )); then
    echo "Branch is behind upstream by ${behind_count} commit(s); refusing to start." >&2
    echo "Synchronise with upstream manually, then rerun the build loop." >&2
    exit 1
  fi

  if (( ahead_count > 0 && ALLOW_AHEAD != 1 )); then
    echo "Branch is ahead of upstream by ${ahead_count} commit(s); refusing to start." >&2
    echo "Push first, or rerun with --allow-ahead." >&2
    exit 1
  fi
}

refuse_if_remote_advanced() {
  local upstream_ref="$1"
  local expected_upstream_head="$2"
  local current_upstream_head

  if [[ -z "$upstream_ref" || -z "$expected_upstream_head" ]]; then
    return 0
  fi

  git fetch --quiet
  current_upstream_head="$(git rev-parse "$upstream_ref")"

  if [[ "$current_upstream_head" != "$expected_upstream_head" ]]; then
    echo "Upstream $upstream_ref advanced during the cycle; refusing to continue." >&2
    echo "Expected upstream: $expected_upstream_head" >&2
    echo "Current upstream:  $current_upstream_head" >&2
    exit 1
  fi
}

acquire_lock() {
  mkdir -p "$(dirname "$LOCK_DIR")" "$LOG_DIR"

  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "Another build loop appears to be running: $LOCK_DIR" >&2
    exit 1
  fi

  echo "$$" > "$LOCK_DIR/pid"
  trap 'rm -rf "$LOCK_DIR"' EXIT
}

require_command git

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git work tree." >&2
  exit 1
fi

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Required file missing: $file" >&2
    exit 1
  fi
done

require_customised_template
acquire_lock

cycle=0

while (( cycle < MAX_CYCLES )); do
  automation_status="$(get_automation_status)"
  if [[ -z "$automation_status" ]]; then
    echo "Missing top-level AUTOMATION_STATUS line in BUILD_TICKETS.md." >&2
    exit 1
  fi
  if [[ "$automation_status" == "DONE" ]]; then
    echo "Build tickets marked done."
    exit 0
  fi

  cycle=$((cycle + 1))
  echo "=== autonomous build cycle $cycle/$MAX_CYCLES ==="

  sync_before_cycle

  before_head="$(git rev-parse HEAD)"
  log_file="$LOG_DIR/cycle-$(date +%Y%m%d-%H%M%S)-$cycle.log"

  echo "Logging to $log_file"

  if ! scripts/run-agent.sh "$PROMPT" 2>&1 | tee "$log_file"; then
    echo "Agent failed during cycle $cycle; stopping. See $log_file" >&2
    exit 1
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Agent left a dirty working tree; stopping for manual review." >&2
    git status --short >&2
    exit 1
  fi

  refuse_if_remote_advanced "$CYCLE_UPSTREAM_REF" "$CYCLE_UPSTREAM_HEAD"

  after_head="$(git rev-parse HEAD)"

  if [[ "$after_head" == "$before_head" ]]; then
    echo "Cycle completed without a new commit; stopping." >&2
    exit 1
  fi

  if (( PUSH_AFTER == 1 )); then
    git push
  fi

  automation_status="$(get_automation_status)"
  if [[ "$automation_status" == "DONE" ]]; then
    echo "Build tickets marked done."
    exit 0
  fi

  if (( SLEEP_SECONDS > 0 )); then
    sleep "$SLEEP_SECONDS"
  fi
done
