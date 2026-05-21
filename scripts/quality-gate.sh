#!/usr/bin/env bash
set -euo pipefail

warn() {
  echo "WARN: $*" >&2
}

have() {
  command -v "$1" >/dev/null 2>&1
}

echo "== shell syntax checks =="
for script in scripts/*.sh; do
  [[ -e "$script" ]] || continue
  bash -n "$script"
done

if [[ -f scripts/check-no-secrets.sh ]]; then
  echo "== secret guardrail =="
  bash scripts/check-no-secrets.sh
fi

if [[ -f scripts/check-no-generated-private-files.sh ]]; then
  echo "== generated/private-file guardrail =="
  bash scripts/check-no-generated-private-files.sh
fi

if [[ -f Makefile ]] && grep -Eq '^[[:space:]]*quality:' Makefile; then
  echo "== make quality =="
  make quality
fi

if [[ -f package.json ]]; then
  echo "== Node project detected =="

  if have npm; then
    if [[ -f package-lock.json ]]; then
      npm ci
    else
      npm install
    fi

    npm run lint --if-present
    npm run typecheck --if-present
    npm test --if-present
    npm run build --if-present
  else
    warn "npm not installed; skipping Node checks"
  fi
fi

if [[ -f pyproject.toml ]]; then
  echo "== Python project detected =="

  if have uv; then
    if [[ -f uv.lock ]]; then
      uv sync --locked --all-groups
    else
      uv sync --all-groups
    fi

    if grep -Eq 'ruff' pyproject.toml; then
      uv run ruff check .
      uv run ruff format --check .
    fi

    if grep -Eq 'mypy' pyproject.toml; then
      uv run mypy .
    fi

    if [[ -d tests ]] && grep -Eq 'pytest' pyproject.toml; then
      uv run pytest
    fi
  elif have python; then
    warn "uv not installed; running minimal Python syntax checks only"
    python -m compileall -q .
  else
    warn "Python tooling not installed; skipping Python checks"
  fi
fi

if find . -path ./.git -prune -o -name '*.tf' -print -quit | grep -q .; then
  echo "== Terraform project detected =="

  if have terraform; then
    terraform fmt -recursive -check

    while IFS= read -r dir; do
      echo "== terraform validate: $dir =="
      (
        cd "$dir"
        terraform init -backend=false
        terraform validate
      )
    done < <(
      find . -path ./.git -prune -o -name '*.tf' -print \
        | while IFS= read -r tf_file; do dirname "$tf_file"; done \
        | sort -u \
        | while IFS= read -r dir; do
            if [[ -f "$dir/main.tf" ]] || [[ -f "$dir/providers.tf" ]]; then
              echo "$dir"
            fi
          done
    )
  else
    warn "terraform not installed; skipping Terraform validation"
  fi
fi

if [[ -f docker-compose.yml ]] || [[ -f compose.yml ]]; then
  echo "== Docker Compose validation =="
  if have docker; then
    if [[ -f docker-compose.yml ]]; then
      docker compose -f docker-compose.yml config >/dev/null
    fi
    if [[ -f compose.yml ]]; then
      docker compose -f compose.yml config >/dev/null
    fi
  else
    warn "docker not installed; skipping Docker Compose validation"
  fi
fi

echo "== quality gate passed =="
