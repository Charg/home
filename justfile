default:
    @just --list

update-claude-code:
    #!/usr/bin/env bash
    set -euo pipefail

    overlays_file="nix/lib/overlays.nix"
    base_url="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

    latest_version="$(curl -fsSL "$base_url/latest")"
    manifest="$(curl -fsSL "$base_url/$latest_version/manifest.json")"

    current_version="$(perl -0777 -ne 'print $1 if /version = "([^"]+)";\s*\n\s*baseUrl = "https:\/\/storage\.googleapis\.com\/claude-code-dist/' "$overlays_file")"

    if [[ -z "$current_version" ]]; then
      echo "error: could not find the current pinned claude-code version in $overlays_file" >&2
      exit 1
    fi

    if [[ "$latest_version" == "$current_version" ]]; then
      echo "claude-code is already pinned to the latest release ($current_version)"
      exit 0
    fi

    echo "Updating claude-code: $current_version -> $latest_version"

    perl -0777 -pi -e "s/version = \"\\Q$current_version\\E\";(\\s*\\n\\s*baseUrl = \"https:\\/\\/storage\\.googleapis\\.com\\/claude-code-dist)/version = \"$latest_version\";\$1/" "$overlays_file"

    for platform in darwin-arm64 darwin-x64 linux-arm64 linux-x64; do
      checksum="$(jq -r --arg p "$platform" '.platforms[$p].checksum // empty' <<<"$manifest")"
      if [[ -z "$checksum" ]]; then
        echo "error: manifest for $latest_version has no checksum for $platform" >&2
        exit 1
      fi
      perl -0777 -pi -e "s/(\"$platform\" = \")[a-f0-9]+(\";)/\${1}$checksum\${2}/" "$overlays_file"
    done

    echo "Updated $overlays_file to claude-code $latest_version"
    echo "Review the diff, then run 'nix flake check' before committing."
