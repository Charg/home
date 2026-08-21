#!/usr/bin/env bash
# Pre-commit hook: assert every staged *.enc* file is actually SOPS ciphertext.
#
# The `.enc` suffix is convention only — nothing else in this repo verifies it.
# `sops filestatus` reports encryption status from file metadata without
# needing an age key, so it works in any clone. Note it exits 0 even when the
# file is plaintext (or unparseable), so we must inspect stdout, not $?.
set -euo pipefail

if ! command -v sops >/dev/null 2>&1; then
  echo "check-sops-encrypted: 'sops' not found on PATH (see pkgs.sops in nix/common/hm-common-pkgs.nix)" >&2
  exit 1
fi

failures=()

for file in "$@"; do
  status="$(sops filestatus "$file" 2>/dev/null || true)"
  if [[ "$status" != *'"encrypted":true'* ]]; then
    failures+=("$file")
  fi
done

if ((${#failures[@]} > 0)); then
  echo "The following files are named like SOPS-encrypted files but are not encrypted:" >&2
  for file in "${failures[@]}"; do
    echo "  $file: not SOPS-encrypted — run: sops -e -i $file" >&2
  done
  exit 1
fi
