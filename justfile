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

update-herdr:
    #!/usr/bin/env bash
    set -euo pipefail

    releases="https://releases.herdr.dev"
    updated=0

    # <release channel> <package file>
    for pair in "core nix/packages/herdr-core.nix" "app nix/packages/herdr-desktop.nix"; do
      read -r channel file <<<"$pair"
      manifest="$(curl -fsSL "$releases/$channel/latest.json")"
      latest_version="$(jq -r '.version' <<<"$manifest")"
      current_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$file")"

      if [[ -z "$current_version" ]]; then
        echo "error: could not find the current pinned version in $file" >&2
        exit 1
      fi

      if [[ "$latest_version" == "$current_version" ]]; then
        echo "herdr $channel is already pinned to the latest release ($current_version)"
        continue
      fi

      echo "Updating herdr $channel: $current_version -> $latest_version"

      perl -pi -e "s/^(\\s*version = \")\\Q$current_version\\E(\";)/\${1}$latest_version\${2}/" "$file"

      for arch in x86_64 aarch64; do
        checksum="$(jq -r --arg t "linux-$arch" '.targets[$t].sha256 // empty' <<<"$manifest")"
        if [[ -z "$checksum" ]]; then
          echo "error: $channel manifest for $latest_version has no checksum for linux-$arch" >&2
          exit 1
        fi
        perl -pi -e "s/(\"$arch-linux\" = \")[a-f0-9]+(\";)/\${1}$checksum\${2}/" "$file"
      done

      updated=1
    done

    if [[ "$updated" == 1 ]]; then
      echo "Review the diff, then run 'nix flake check' before committing."
    fi
