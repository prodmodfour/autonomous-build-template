#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: scripts/run-agent.sh '<prompt>'" >&2
  exit 2
fi

PROMPT="$1"

if ! command -v pi >/dev/null 2>&1; then
  echo "Required command not found: pi" >&2
  echo "Edit scripts/run-agent.sh if this project should use a different agent command." >&2
  exit 127
fi

# Intentionally no model or thinking-level flags.
# This relies on the local pi configuration.

pi --no-session -p @AGENTS.md @PROJECT_BRIEF.md @BUILD_TICKETS.md @BUILD_NOTES.md "$PROMPT"
