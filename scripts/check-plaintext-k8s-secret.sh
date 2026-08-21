#!/usr/bin/env bash
# Pre-commit hook: catch a plaintext Kubernetes Secret manifest that never
# got the *.enc.yaml suffix (and so would never be seen by
# check-sops-encrypted.sh, which only looks at *.enc* files).
set -euo pipefail

failures=()

for file in "$@"; do
  if grep -qE '^kind:[[:space:]]*Secret[[:space:]]*$' "$file"; then
    failures+=("$file")
  fi
done

if ((${#failures[@]} > 0)); then
  echo "The following manifests declare 'kind: Secret' without being SOPS-encrypted:" >&2
  for file in "${failures[@]}"; do
    echo "  $file: plaintext kind: Secret — rename to *.enc.yaml and encrypt with sops -e -i" >&2
  done
  exit 1
fi
