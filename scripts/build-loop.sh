#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/pretty-print.sh
source "$SCRIPT_DIR/lib/pretty-print.sh"
# shellcheck source=scripts/lib/git-branch.sh
source "$SCRIPT_DIR/lib/git-branch.sh"

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
* pushes the new commit unless --no-push is used
* leaves the working tree clean

Options:
--max-cycles N     Number of cycles to run. Default: 1.
--sleep SECONDS    Pause between successful cycles. Default: 0.
--no-push          Do not push after successful cycles. By default, each new commit is pushed.
--push             Push after successful cycles (default; kept for compatibility).
--branch NAME      Select an existing local branch, or a unique remote branch, before running.
--create-branch NAME
                   Create and select a new branch before running.
--branch-start REF Start point for --create-branch. Default: HEAD.
--allow-ahead      Allow starting when branch is already ahead of upstream (default; kept for compatibility).
--allow-template   Allow running even if PROJECT_BRIEF.md is still marked uncustomised.
-h, --help         Show this help.

Environment:
AUTONOMOUS_BUILD_LOOP_STATE_DIR
                   Override the per-repository state directory used for build-loop
                   logs and lock files. Defaults outside the repository under
                   ${XDG_STATE_HOME:-$HOME/.local/state}/autonomous-build-template/build-loop/<repo-key>.
AUTONOMOUS_BUILD_RETRY_SECONDS
                   Seconds to wait before retrying after transient agent failures.
                   Defaults to 600 (10 minutes).

This script intentionally does not pass a model or thinking level.
Agent invocation is delegated to scripts/run-agent.sh.
USAGE
}

MAX_CYCLES=1
SLEEP_SECONDS=0
PUSH_AFTER=1
SELECT_BRANCH=""
CREATE_BRANCH=""
BRANCH_START_POINT="HEAD"
BRANCH_START_SET=0
ALLOW_AHEAD=1
ALLOW_TEMPLATE=0
AGENT_RETRY_SECONDS="${AUTONOMOUS_BUILD_RETRY_SECONDS:-600}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --max-cycles)
      if [[ $# -lt 2 ]]; then
        pp_error "--max-cycles requires a value"
        usage >&2
        exit 2
      fi
      MAX_CYCLES="$2"
      shift 2
      ;;
    --sleep)
      if [[ $# -lt 2 ]]; then
        pp_error "--sleep requires a value"
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
    --no-push)
      PUSH_AFTER=0
      shift
      ;;
    --branch)
      if [[ $# -lt 2 ]]; then
        pp_error "--branch requires a value"
        usage >&2
        exit 2
      fi
      SELECT_BRANCH="$2"
      shift 2
      ;;
    --create-branch)
      if [[ $# -lt 2 ]]; then
        pp_error "--create-branch requires a value"
        usage >&2
        exit 2
      fi
      CREATE_BRANCH="$2"
      shift 2
      ;;
    --branch-start)
      if [[ $# -lt 2 ]]; then
        pp_error "--branch-start requires a value"
        usage >&2
        exit 2
      fi
      BRANCH_START_POINT="$2"
      BRANCH_START_SET=1
      shift 2
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
      pp_error "Unknown argument: $1"
      usage >&2
      exit 2
      ;;
  esac
done

if ! [[ "$MAX_CYCLES" =~ ^[0-9]+$ ]] || [[ "$MAX_CYCLES" -lt 1 ]]; then
  pp_error "--max-cycles must be a positive integer"
  exit 2
fi

if ! [[ "$SLEEP_SECONDS" =~ ^[0-9]+$ ]]; then
  pp_error "--sleep must be a non-negative integer"
  exit 2
fi

if ! [[ "$AGENT_RETRY_SECONDS" =~ ^[0-9]+$ ]]; then
  pp_error "AUTONOMOUS_BUILD_RETRY_SECONDS must be a non-negative integer"
  exit 2
fi

if [[ -n "$SELECT_BRANCH" && -n "$CREATE_BRANCH" ]]; then
  pp_error "--branch and --create-branch cannot be used together"
  exit 2
fi

if (( BRANCH_START_SET == 1 )) && [[ -z "$CREATE_BRANCH" ]]; then
  pp_error "--branch-start requires --create-branch"
  exit 2
fi

REQUIRED_FILES=(
  AGENTS.md
  PROJECT_BRIEF.md
  BUILD_TICKETS.md
  BUILD_NOTES.md
  scripts/quality-gate.sh
  scripts/run-agent.sh
  scripts/lib/pretty-print.sh
  scripts/lib/git-branch.sh
)

BUILD_LOOP_STATE_DIR=""
LOG_DIR=""
LOCK_DIR=""
CYCLE_UPSTREAM_REF=""
CYCLE_UPSTREAM_HEAD=""

PROMPT=$(cat <<'PROMPT_EOF'
You are continuing an autonomous ticket-driven build.

Read AGENTS.md, PROJECT_BRIEF.md, BUILD_TICKETS.md, and BUILD_NOTES.md.

Your task in this run:

* Select the lowest-numbered TODO or IN_PROGRESS ticket from BUILD_TICKETS.md.
* At the start of the run, print a short "Now working on ..." line naming the selected ticket and immediate action.
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

SPLIT_TICKET_PROMPT=$(cat <<'PROMPT_EOF'
You are running a recovery task for an autonomous build loop after the implementation agent failed with a token or context-length error.

This recovery task overrides the normal implementation workflow in AGENTS.md.

Read AGENTS.md, PROJECT_BRIEF.md, BUILD_TICKETS.md, and BUILD_NOTES.md.

Your only task in this run:

* Identify the lowest-numbered TODO or IN_PROGRESS ticket in BUILD_TICKETS.md.
* Split that one ticket into two smaller, sequential, independently actionable tickets.
* Preserve the original intent and acceptance criteria across the two new tickets.
* Make the first ticket a narrow foundation or vertical slice.
* Make the second ticket the remaining behaviour, integration, documentation, or validation work.
* Keep both tickets small enough for separate future autonomous runs.
* Preserve the original status on the first split ticket if it was IN_PROGRESS; otherwise use TODO.
* Set the second split ticket to TODO.
* Renumber later tickets if needed to keep ordering clear.
* Do not implement product code.
* Do not start or complete any ticket.
* Do not run the normal quality gate unless you need it to validate this ticket-file-only edit.
* Update BUILD_NOTES.md with a short recovery note explaining that the original ticket was split because the previous run hit a token/context-length limit.
* Commit only BUILD_TICKETS.md and BUILD_NOTES.md with a conventional commit message such as "chore: split oversized build ticket".
* Leave the working tree clean.
PROMPT_EOF
)

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    pp_error "Required command not found: $1"
    exit 127
  fi
}

run_agent_with_log() {
  local prompt="$1"
  local log_file="$2"
  local -a pipeline_status
  local agent_status
  local tee_status

  set +e
  scripts/run-agent.sh "$prompt" 2>&1 | tee "$log_file"
  pipeline_status=("${PIPESTATUS[@]}")
  set -e

  agent_status="${pipeline_status[0]}"
  tee_status="${pipeline_status[1]}"

  if (( tee_status != 0 )); then
    pp_error "Failed to write agent log: $log_file"
    return 125
  fi

  return "$agent_status"
}

is_token_context_failure() {
  local log_file="$1"

  [[ -f "$log_file" ]] || return 1

  grep -Eiq '(context[_ -]?length|context window|context_length_exceeded|maximum context|max context|context limit)' "$log_file" && return 0
  grep -Eiq '(too many tokens|too much input|token limit|token budget|maximum tokens|max tokens|exceed(ed|s|ing)?[^[:cntrl:]]{0,120}tokens|tokens[^[:cntrl:]]{0,120}exceed(ed|s|ing)?)' "$log_file" && return 0
  grep -Eiq '((input|prompt)[^[:cntrl:]]{0,80}(too long|too large|exceed(ed|s|ing)?)|maximum (input|prompt) length|request too large)' "$log_file" && return 0

  return 1
}

sleep_before_agent_retry() {
  local reason="$1"

  if (( AGENT_RETRY_SECONDS > 0 )); then
    pp_warn "$reason; retrying in ${AGENT_RETRY_SECONDS}s."
    sleep "$AGENT_RETRY_SECONDS"
  else
    pp_warn "$reason; retrying immediately."
  fi
}

git_clean_preserving_build_loop_state() {
  local repo_root
  local repo_abs
  local state_abs
  local state_rel

  repo_root="$(git rev-parse --show-toplevel)"
  repo_abs="$(cd "$repo_root" && pwd -P)"
  state_abs="$(cd "$BUILD_LOOP_STATE_DIR" 2>/dev/null && pwd -P || true)"

  if [[ -n "$state_abs" && "$state_abs" == "$repo_abs"/* ]]; then
    state_rel="${state_abs#"$repo_abs"/}"
    pp_cmd "git clean -fd -e $state_rel/"
    git clean -fd -e "$state_rel/" >/dev/null
  else
    pp_cmd "git clean -fd"
    git clean -fd >/dev/null
  fi
}

restore_clean_tree_after_failed_agent() {
  local before_head="$1"
  local current_head

  current_head="$(git rev-parse HEAD)"
  if [[ "$current_head" != "$before_head" ]]; then
    pp_error "Agent changed HEAD before failing; stopping for manual review."
    pp_hint "Before failure: $before_head"
    pp_hint "Current HEAD:    $current_head"
    return 1
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    pp_warn "Agent left uncommitted changes after failure; restoring the pre-run clean tree."
    pp_cmd "git reset --hard $before_head"
    git reset --hard "$before_head" >/dev/null
    git_clean_preserving_build_loop_state
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    pp_error "Unable to restore a clean working tree after failed agent run."
    git status --short >&2
    return 1
  fi
}

require_clean_tree() {
  git_branch_require_clean_tree || exit 1
}

require_customised_template() {
  if (( ALLOW_TEMPLATE == 1 )); then
    return 0
  fi

  if grep -Eq '^TEMPLATE_CUSTOMISED:[[:space:]]*false[[:space:]]*$' PROJECT_BRIEF.md; then
    pp_error "PROJECT_BRIEF.md is still marked TEMPLATE_CUSTOMISED: false."
    pp_hint "Edit PROJECT_BRIEF.md for this project and set TEMPLATE_CUSTOMISED: true before running."
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

get_next_ticket_summary() {
  awk '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }

    function record_if_current() {
      if (ticket_number != "" && (ticket_status == "TODO" || ticket_status == "IN_PROGRESS")) {
        ticket_value = ticket_number + 0
        if (!found || ticket_value < best_value) {
          found = 1
          best_value = ticket_value
          best_number = ticket_number
          best_title = ticket_title
          best_status = ticket_status
        }
      }
    }

    /^##[[:space:]]+[0-9]+([[:space:]]|$)/ {
      record_if_current()

      heading = $0
      sub(/^##[[:space:]]+/, "", heading)

      ticket_number = heading
      sub(/[[:space:]].*$/, "", ticket_number)

      ticket_title = heading
      sub(/^[0-9]+[[:space:]]+/, "", ticket_title)
      sub(/^[-—][[:space:]]*/, "", ticket_title)

      ticket_status = ""
      next
    }

    ticket_number != "" && /^Status:/ {
      ticket_status = $0
      sub(/^Status:[[:space:]]*/, "", ticket_status)
      ticket_status = trim(ticket_status)
    }

    END {
      record_if_current()
      if (found) {
        printf "%s — %s (%s)\n", best_number, best_title, best_status
      }
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
    pp_info "No upstream configured; skipping remote sync checks."
    pp_success "Pre-flight checks passed."
    return 0
  fi

  git fetch --quiet
  CYCLE_UPSTREAM_HEAD="$(git rev-parse "$upstream_ref")"
  counts="$(git rev-list --left-right --count "${upstream_ref}...HEAD")"
  read -r behind_count ahead_count <<< "$counts"

  if (( behind_count > 0 )); then
    pp_error "Branch is behind upstream by ${behind_count} commit(s); refusing to start."
    pp_hint "Synchronise with upstream manually, then rerun the build loop."
    exit 1
  fi

  pp_kv "Upstream" "$upstream_ref"
  pp_kv "Behind" "$behind_count commit(s)"
  pp_kv "Ahead" "$ahead_count commit(s)"
  pp_success "Pre-flight checks passed."
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
    pp_error "Upstream $upstream_ref advanced during the cycle; refusing to continue."
    pp_kv "Expected upstream" "$expected_upstream_head" >&2
    pp_kv "Current upstream" "$current_upstream_head" >&2
    exit 1
  fi
}

split_current_ticket_after_context_failure() {
  local split_before_head
  local split_log
  local split_status
  local split_after_head

  pp_section "Token/context recovery"
  pp_warn "Detected a token/context-length failure in the agent log."
  pp_info "Asking the configured Pi agent wrapper to split the current ticket into two smaller tickets."

  split_before_head="$(git rev-parse HEAD)"
  mkdir -p "$LOG_DIR"
  log_sequence=$((log_sequence + 1))
  split_log="$LOG_DIR/split-ticket-$(date +%Y%m%d-%H%M%S)-$cycle-$log_sequence.log"

  pp_kv "Split log file" "$split_log"

  if run_agent_with_log "$SPLIT_TICKET_PROMPT" "$split_log"; then
    split_status=0
  else
    split_status=$?
  fi

  if (( split_status != 0 )); then
    pp_error "Ticket split agent failed with exit status $split_status."
    pp_hint "See $split_log"
    if (( split_status == 130 || split_status == 143 )); then
      pp_error "Ticket split agent was interrupted; stopping."
      return 2
    fi
    restore_clean_tree_after_failed_agent "$split_before_head" || return 2
    return 1
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    pp_error "Ticket split agent left a dirty working tree; stopping for manual review."
    git status --short >&2
    return 2
  fi

  split_after_head="$(git rev-parse HEAD)"
  if [[ "$split_after_head" == "$split_before_head" ]]; then
    pp_error "Ticket split recovery completed without a new commit; stopping."
    return 2
  fi

  refuse_if_remote_advanced "$CYCLE_UPSTREAM_REF" "$CYCLE_UPSTREAM_HEAD"

  pp_success "Ticket split committed $(git rev-parse --short HEAD)"

  if (( PUSH_AFTER == 1 )); then
    pp_section "Push ticket split"
    git_branch_push_current origin
  fi
}

sanitize_state_component() {
  local value="$1"
  local sanitized

  sanitized="$(printf '%s' "$value" | tr -c 'A-Za-z0-9._-' '-')"
  sanitized="${sanitized:0:80}"

  if [[ -z "$sanitized" ]]; then
    sanitized="repo"
  fi

  printf '%s\n' "$sanitized"
}

configure_build_loop_state_paths() {
  local repo_root
  local repo_name
  local repo_slug
  local repo_hash
  local state_home
  local state_dir

  if [[ -n "${AUTONOMOUS_BUILD_LOOP_STATE_DIR:-}" ]]; then
    state_dir="$AUTONOMOUS_BUILD_LOOP_STATE_DIR"
  else
    if [[ -n "${XDG_STATE_HOME:-}" ]]; then
      state_home="$XDG_STATE_HOME"
    elif [[ -n "${HOME:-}" ]]; then
      state_home="$HOME/.local/state"
    else
      pp_error "HOME must be set when XDG_STATE_HOME and AUTONOMOUS_BUILD_LOOP_STATE_DIR are not set."
      exit 1
    fi

    repo_root="$(git rev-parse --show-toplevel)"
    repo_name="$(basename "$repo_root")"
    repo_slug="$(sanitize_state_component "$repo_name")"
    repo_hash="$(printf '%s' "$repo_root" | git hash-object --stdin | cut -c 1-12)"
    state_dir="$state_home/autonomous-build-template/build-loop/${repo_slug}-${repo_hash}"
  fi

  BUILD_LOOP_STATE_DIR="$state_dir"
  LOG_DIR="$BUILD_LOOP_STATE_DIR/logs"
  LOCK_DIR="$BUILD_LOOP_STATE_DIR/lock"
}

acquire_lock() {
  mkdir -p "$BUILD_LOOP_STATE_DIR" "$LOG_DIR"

  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    pp_error "Another build loop appears to be running: $LOCK_DIR"
    exit 1
  fi

  echo "$$" > "$LOCK_DIR/pid"
  trap 'rm -rf "$LOCK_DIR"' EXIT
}

require_command git

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  pp_error "Not inside a git work tree."
  exit 1
fi

configure_build_loop_state_paths
acquire_lock

pp_banner "Autonomous build loop"
pp_kv "Max cycles" "$MAX_CYCLES"
pp_kv "Sleep" "${SLEEP_SECONDS}s"
pp_kv "Agent retry sleep" "${AGENT_RETRY_SECONDS}s"
pp_kv "Push after commit" "$(pp_on_off "$PUSH_AFTER")"
if [[ -n "$SELECT_BRANCH" ]]; then
  pp_kv "Select branch" "$SELECT_BRANCH"
elif [[ -n "$CREATE_BRANCH" ]]; then
  pp_kv "Create branch" "$CREATE_BRANCH"
  pp_kv "Branch start" "$BRANCH_START_POINT"
fi
pp_kv "Allow ahead" "$(pp_on_off "$ALLOW_AHEAD")"
pp_kv "State dir" "$BUILD_LOOP_STATE_DIR"
pp_kv "Logs" "$LOG_DIR"

if [[ -n "$SELECT_BRANCH" || -n "$CREATE_BRANCH" ]]; then
  pp_section "Branch setup"
  git_branch_prepare "$SELECT_BRANCH" "$CREATE_BRANCH" "$BRANCH_START_POINT" || exit $?
fi

pp_kv "Current branch" "$(git_branch_current)"

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    pp_error "Required file missing: $file"
    exit 1
  fi
done

require_customised_template

cycle=0
log_sequence=0

while (( cycle < MAX_CYCLES )); do
  automation_status="$(get_automation_status)"
  if [[ -z "$automation_status" ]]; then
    pp_error "Missing top-level AUTOMATION_STATUS line in BUILD_TICKETS.md."
    exit 1
  fi
  if [[ "$automation_status" == "DONE" ]]; then
    pp_success "Build tickets marked done."
    exit 0
  fi

  cycle=$((cycle + 1))
  pp_banner "Autonomous build cycle" "$cycle/$MAX_CYCLES"

  pp_section "Current work"
  next_ticket="$(get_next_ticket_summary)"
  if [[ -n "$next_ticket" ]]; then
    pp_info "Now working on: ticket $next_ticket"
  else
    pp_warn "No TODO or IN_PROGRESS ticket found; agent will inspect BUILD_TICKETS.md."
  fi

  pp_section "Pre-flight checks"
  sync_before_cycle

  before_head="$(git rev-parse HEAD)"
  mkdir -p "$LOG_DIR"
  log_sequence=$((log_sequence + 1))
  log_file="$LOG_DIR/cycle-$(date +%Y%m%d-%H%M%S)-$cycle-$log_sequence.log"

  pp_kv "Log file" "$log_file"
  pp_section "Agent run"

  if run_agent_with_log "$PROMPT" "$log_file"; then
    agent_status=0
  else
    agent_status=$?
  fi

  if (( agent_status != 0 )); then
    if (( agent_status == 125 )); then
      pp_error "Agent log capture failed during cycle $cycle; stopping."
      pp_hint "See $log_file"
      exit 1
    fi

    if (( agent_status == 130 || agent_status == 143 )); then
      pp_error "Agent was interrupted during cycle $cycle; stopping."
      pp_hint "See $log_file"
      exit "$agent_status"
    fi

    pp_error "Agent failed during cycle $cycle with exit status $agent_status."
    pp_hint "See $log_file"

    if ! restore_clean_tree_after_failed_agent "$before_head"; then
      exit 1
    fi

    if is_token_context_failure "$log_file"; then
      if split_current_ticket_after_context_failure; then
        pp_info "Continuing with the split ticket queue."
        cycle=$((cycle - 1))
        continue
      else
        split_recovery_status=$?
        if (( split_recovery_status == 2 )); then
          exit 1
        fi
        sleep_before_agent_retry "Ticket split recovery failed"
        cycle=$((cycle - 1))
        continue
      fi
    fi

    sleep_before_agent_retry "Agent failed; assuming a transient provider/server issue"
    cycle=$((cycle - 1))
    continue
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    pp_error "Agent left a dirty working tree; stopping for manual review."
    git status --short >&2
    exit 1
  fi

  refuse_if_remote_advanced "$CYCLE_UPSTREAM_REF" "$CYCLE_UPSTREAM_HEAD"

  after_head="$(git rev-parse HEAD)"

  if [[ "$after_head" == "$before_head" ]]; then
    pp_error "Cycle completed without a new commit; stopping."
    exit 1
  fi

  pp_success "Cycle committed $(git rev-parse --short HEAD)"

  if (( PUSH_AFTER == 1 )); then
    pp_section "Push"
    git_branch_push_current origin
  fi

  automation_status="$(get_automation_status)"
  if [[ "$automation_status" == "DONE" ]]; then
    pp_success "Build tickets marked done."
    exit 0
  fi

  if (( SLEEP_SECONDS > 0 )); then
    pp_info "Sleeping ${SLEEP_SECONDS}s before next cycle."
    sleep "$SLEEP_SECONDS"
  fi
done
