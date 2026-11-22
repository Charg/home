#!/usr/bin/env bash
# Report which flake configurations a change alters, by comparing the
# top-level derivation path of every NixOS, darwin and standalone Home Manager
# configuration between a base git ref and the working tree. Evaluation only;
# nothing is built.
#
# Usage: scripts/config-identity.sh [base-ref]   (default: main)
set -uo pipefail

base_ref="${1:-main}"
root="$(git rev-parse --show-toplevel)"
base_rev="$(git -C "$root" rev-parse --verify "$base_ref^{commit}")" || exit 1

# The working tree is evaluated as a git flake, so uncommitted changes to
# tracked files count (new files need `git add`, as for any flake command).
# The base ref is fetched by revision straight from the git store, so nothing
# is checked out.
work_flake="git+file://$root"
base_flake="git+file://$root?rev=$base_rev"

jobs="${CONFIG_IDENTITY_JOBS:-$(nproc)}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Output attribute -> expression yielding the configuration's top-level drv.
list_configs() {
  nix eval --json "$1#." --apply '
    flake:
    let
      names = attr: builtins.attrNames (flake.${attr} or { });
      tag = attr: suffix: map (n: { inherit attr n suffix; }) (names attr);
    in
    tag "nixosConfigurations" "config.system.build.toplevel"
    ++ tag "darwinConfigurations" "config.system.build.toplevel"
    ++ tag "homeConfigurations" "activationPackage"
  ' | jq -r '.[] | "\(.attr)\t\(.n)\t\(.suffix)"'
}

{
  list_configs "$work_flake" || echo "error: cannot list configurations in the working tree" >&2
  list_configs "$base_flake" || echo "error: cannot list configurations at $base_ref" >&2
} | sort -u >"$tmp/configs"

[[ -s "$tmp/configs" ]] || exit 1

eval_one() {
  local side="$1" flake="$2" attr="$3" name="$4" suffix="$5"
  local out="$tmp/$side.$attr.$name"
  if nix eval --raw "$flake#$attr.\"$name\".$suffix.drvPath" >"$out" 2>"$out.err"; then
    :
  else
    rm -f "$out"
  fi
}
export -f eval_one
export tmp

# None of these fields contain whitespace, so xargs can split on it.
while IFS=$'\t' read -r attr name suffix; do
  echo base "$base_flake" "$attr" "$name" "$suffix"
  echo work "$work_flake" "$attr" "$name" "$suffix"
done <"$tmp/configs" |
  xargs -P "$jobs" -n 5 bash -c 'eval_one "$@"' _

changed=0
failed=0
while IFS=$'\t' read -r attr name _; do
  base="$tmp/base.$attr.$name"
  work="$tmp/work.$attr.$name"
  label="$attr.$name"
  if [[ ! -f "$work" || ! -f "$base" ]]; then
    which=()
    [[ -f "$base" ]] || which+=("base")
    [[ -f "$work" ]] || which+=("working tree")
    printf '%-14s %s (%s)\n' "EVAL-FAILED" "$label" "$(IFS=,; echo "${which[*]}")"
    for side in base work; do
      err="$tmp/$side.$attr.$name.err"
      [[ -f "$tmp/$side.$attr.$name" || ! -s "$err" ]] && continue
      # The innermost error is the last `error:` line nix prints.
      grep -E '^\s*error:' "$err" | tail -n1 | sed -E "s/^\s*/    $side: /"
    done
    failed=$((failed + 1))
  elif [[ "$(<"$base")" == "$(<"$work")" ]]; then
    printf '%-14s %s\n' "identical" "$label"
  else
    printf '%-14s %s\n' "CHANGED" "$label"
    printf '    base: %s\n    work: %s\n' "$(<"$base")" "$(<"$work")"
    changed=$((changed + 1))
  fi
done <"$tmp/configs"

echo
echo "$changed changed, $failed failed to evaluate (base: $base_ref @ ${base_rev:0:12})"
[[ $changed -eq 0 && $failed -eq 0 ]]
