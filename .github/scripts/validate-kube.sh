#!/usr/bin/env bash
# Validate the kube/ changes between a base ref and HEAD.
#
#   validate-kube.sh <base-ref>
#
# Charts: every ApplicationSet element whose entry or values.yaml changed is
# rendered with `helm template` and the output checked with kubeconform.
# Manifests: plain YAML in any other changed app directory is checked with
# kubeconform. SOPS-encrypted files and values.yaml are skipped.
set -euo pipefail

base=$1
kube_version=${KUBE_VERSION:-1.35.0}
# CRD APIs the cluster serves, so charts that gate on .Capabilities render.
api_versions=(
  monitoring.coreos.com/v1
  cert-manager.io/v1
  traefik.io/v1alpha1
  metallb.io/v1beta1
  postgresql.cnpg.io/v1
  barmancloud.cnpg.io/v1
  redis.redis.opstreelabs.in/v1beta2
)
work=${RUNNER_TEMP:-$(mktemp -d)}/validate-kube
rm -rf "$work" && mkdir -p "$work"

kubeconform_args=(
  -strict
  -summary
  -ignore-missing-schemas
  -kubernetes-version "$kube_version"
  -schema-location default
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
)

mapfile -t changed < <(git diff --name-only "$base"...HEAD -- kube/)
if [ ${#changed[@]} -eq 0 ]; then
  echo "No kube/ changes."
  exit 0
fi

failed=0
declare -A chart_apps=() chart_dirs=()

elements() {
  # $1: git rev (empty for the working tree), $2: cluster
  local file="kube/$2/app-of-apps/application_set_apps.yaml"
  if [ -z "$1" ]; then
    [ -f "$file" ] && yq -o json '.spec.generators[0].list.elements' "$file"
  else
    git show "$1:$file" 2>/dev/null | yq -o json '.spec.generators[0].list.elements'
  fi || echo '[]'
}

for cluster_dir in kube/*/; do
  cluster=$(basename "$cluster_dir")
  head_els=$(elements "" "$cluster")
  base_els=$(elements "$base" "$cluster")

  # Elements added or modified in the ApplicationSet.
  while read -r name; do
    [ -n "$name" ] && chart_apps["$cluster/$name"]=1
  done < <(jq -rn --argjson h "$head_els" --argjson b "$base_els" \
    '$h[] as $e | select(($b | index([$e])) == null) | $e.name')

  # Elements whose values.yaml changed.
  while read -r name; do
    if printf '%s\n' "${changed[@]}" | grep -qx "kube/$cluster/$name/values.yaml"; then
      chart_apps["$cluster/$name"]=1
    fi
    chart_dirs["$cluster/$name"]=1
  done < <(jq -r '.[].name' <<<"$head_els")

  for key in "${!chart_apps[@]}"; do
    [[ $key == "$cluster/"* ]] || continue
    name=${key#*/}
    el=$(jq -c --arg n "$name" '.[] | select(.name == $n)' <<<"$head_els")
    repo=$(jq -r .repoURL <<<"$el")
    chart=$(jq -r .chart <<<"$el")
    version=$(jq -r .targetRevision <<<"$el")
    namespace=$(jq -r .namespace <<<"$el")
    values="kube/$cluster/$name/values.yaml"

    args=(template "$name" --namespace "$namespace" --version "$version"
      --kube-version "$kube_version" --include-crds)
    for api in "${api_versions[@]}"; do args+=(--api-versions "$api"); done
    [ -f "$values" ] && args+=(--values "$values")
    if [[ $repo == http* ]]; then
      args+=(--repo "$repo" "$chart")
    else
      args+=("oci://$repo/$chart")
    fi

    echo "::group::chart $cluster/$name ($chart $version)"
    if helm "${args[@]}" >"$work/$cluster-$name.yaml" &&
      kubeconform "${kubeconform_args[@]}" "$work/$cluster-$name.yaml"; then
      echo "::endgroup::"
    else
      echo "::endgroup::"
      echo "::error::chart $cluster/$name ($chart $version) failed validation"
      failed=1
    fi
  done
done

# Plain manifests in changed directories that are not chart values dirs.
mapfile -t dirs < <(printf '%s\n' "${changed[@]}" | xargs -rn1 dirname | sort -u)
for dir in "${dirs[@]}"; do
  [ -d "$dir" ] || continue
  rel=${dir#kube/}
  [ -n "${chart_dirs[$rel]:-}" ] && continue
  mapfile -t files < <(find "$dir" -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) \
    ! -name '*.enc.yaml' ! -name '*.enc.yml' ! -name 'values.yaml' | sort)
  [ ${#files[@]} -eq 0 ] && continue

  echo "::group::manifests $dir"
  if kubeconform "${kubeconform_args[@]}" "${files[@]}"; then
    echo "::endgroup::"
  else
    echo "::endgroup::"
    echo "::error::manifests in $dir failed validation"
    failed=1
  fi
done

exit $failed
