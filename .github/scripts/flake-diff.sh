#!/usr/bin/env bash
# Render a markdown report of what a flake.lock/flake.nix change upgrades.
#
#   flake-diff.sh <base-checkout> <head-checkout>
#
# Lists bumped flake inputs, then per-host package version changes from
# flake-packages.nix (evaluated, not built). Writes markdown to stdout.
set -euo pipefail

base=$(realpath "$1")
head=$(realpath "$2")
script_dir=$(dirname "$(realpath "$0")")

inventory() {
  nix eval --impure --json --expr \
    "import ${script_dir}/flake-packages.nix { flake = builtins.getFlake \"$1\"; }"
}

echo '<!-- flake-lock-diff -->'
echo '### Flake input changes'
echo
jq -rn --slurpfile old "$base/flake.lock" --slurpfile new "$head/flake.lock" '
  def short: if . == null then "—" else .[0:8] end;
  def link($o; $n):
    if $n.type == "github" and $o != null and $o.rev != $n.rev
    then " ([compare](https://github.com/\($n.owner)/\($n.repo)/compare/\($o.rev)...\($n.rev)))"
    else "" end;
  ($old[0].nodes | with_entries(select(.value.locked))) as $o
  | ($new[0].nodes | with_entries(select(.value.locked))) as $n
  | [ ($o + $n | keys[]) as $k
      | select(($o[$k].locked.narHash) != ($n[$k].locked.narHash))
      | "| `\($k)` | \($o[$k].locked.rev | short) | \($n[$k].locked.rev | short)\(link($o[$k].locked; $n[$k].locked // {})) |" ]
  | if length == 0 then "No input changes."
    else (["| Input | From | To |", "|---|---|---|"] + .) | join("\n") end
'
echo

inventory "$base" >"$RUNNER_TEMP/old.json"
inventory "$head" >"$RUNNER_TEMP/new.json"

echo '### Package changes'
echo
jq -rn --slurpfile old "$RUNNER_TEMP/old.json" --slurpfile new "$RUNNER_TEMP/new.json" '
  $old[0] as $o | $new[0] as $n
  | [ ($o + $n | keys[]) as $h
      | ($o[$h] // {}) as $a | ($n[$h] // {}) as $b
      | [ ($a + $b | keys[]) as $p
          | if $a[$p] == null then "+ \($p) \($b[$p])"
            elif $b[$p] == null then "- \($p) \($a[$p])"
            elif $a[$p] != $b[$p] then "~ \($p): \($a[$p]) → \($b[$p])"
            else empty end ] as $lines
      | select($lines | length > 0)
      | "<details><summary><b>\($h)</b> — \($lines | length) change(s)</summary>\n\n```diff\n\($lines | join("\n"))\n```\n</details>" ]
  | if length == 0 then "No package version changes on any host."
    else join("\n\n") end
'
