#!/usr/bin/env bash
set -euo pipefail

echo "Checking for generated/private files..."

fail=0

while IFS= read -r file; do
  [[ -f "$file" ]] || continue

  case "$file" in
    *.tfstate|*.tfstate.*|*.tfplan)
      echo "Do not commit Terraform state or plan files: $file"
      fail=1
      ;;
    *.tfvars)
      case "$file" in
        *.tfvars.example)
          ;;
        *)
          echo "Do not commit real Terraform variable files: $file"
          fail=1
          ;;
      esac
      ;;
    *.env|*.env.*)
      case "$file" in
        .env.example|*.env.example)
          ;;
        *)
          echo "Do not commit real environment files: $file"
          fail=1
          ;;
      esac
      ;;
    *.pem|*.key|*.p12|*.pfx|id_rsa|*/id_rsa|id_ed25519|*/id_ed25519)
      echo "Do not commit private key/certificate material: $file"
      fail=1
      ;;
  esac
done < <(git ls-files --cached --others --exclude-standard)

if (( fail != 0 )); then
  echo "Generated/private file check failed." >&2
  exit 1
fi

echo "No generated/private files found."
