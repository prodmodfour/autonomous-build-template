#!/usr/bin/env bash
set -euo pipefail

echo "Scanning for obvious committed secrets..."

fail=0
match_file="/tmp/secret-scan-match"
aws_key_regex='AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}'
private_key_regex='-----BEGIN (RSA |OPENSSH |EC |DSA |)PRIVATE KEY-----'
secret_assignment_regex='(password|passwd|secret|token|api[_-]?key|private[_-]?key)[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9_./+=-]{16,}'

# Search tracked and untracked non-ignored files, excluding .git and agent logs.
while IFS= read -r file; do
  [[ -f "$file" ]] || continue

  case "$file" in
    .git/*|.agent/*|.pi/*|node_modules/*|.venv/*|.terraform/*)
      continue
      ;;
  esac

  if grep -nE -- "$aws_key_regex" "$file" >"$match_file" 2>/dev/null; then
    echo "Possible AWS access key found in $file"
    cat "$match_file"
    fail=1
  fi

  if grep -nE -- "$private_key_regex" "$file" >"$match_file" 2>/dev/null; then
    echo "Private key material found in $file"
    cat "$match_file"
    fail=1
  fi

  if grep -nEi -- "$secret_assignment_regex" "$file" >"$match_file" 2>/dev/null; then
    case "$file" in
      PROJECT_BRIEF.md|AGENTS.md|BUILD_TICKETS.md|README.md|docs/*|scripts/check-no-secrets.sh)
        # These files contain instructional examples. Do not fail on generic documentation.
        ;;
      *)
        echo "Possible secret assignment found in $file"
        cat "$match_file"
        fail=1
        ;;
    esac
  fi
done < <(git ls-files --cached --others --exclude-standard)

rm -f "$match_file"

if (( fail != 0 )); then
  echo "Secret scan failed." >&2
  exit 1
fi

echo "No obvious secrets found."
