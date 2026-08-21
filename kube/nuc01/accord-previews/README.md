# accord-previews

Ephemeral per-pull-request environments for [Charg/accord](https://github.com/Charg/accord).

Labelling a PR `preview` makes an environment appear at
`https://pr-<n>.accord.packet.fail` (tailnet only) within a couple of minutes.
Removing the label, or closing the PR, deletes it.

## How it works

`applicationset.yaml` holds an Argo CD `ApplicationSet` with a `pullRequest`
generator. It polls the accord repo every 120 s for open PRs labelled `preview`
and renders one `Application` per PR:

| | |
|---|---|
| Application | `accord-pr-<n>` |
| Namespace | `accord-pr-<n>` (created on sync, deleted on prune) |
| Chart | `helm/accord` from the accord repo at the PR's **head commit** |
| Values | the chart's `values-preview.yaml`, plus `image.tag` and `preview.host` |
| Image | `ghcr.io/charg/accord:pr-<n>-<head_short_sha>` |

The image tag is deliberately sha-suffixed rather than the moving `pr-<n>` tag:
Argo diffs rendered manifests, not registry digests, so a tag whose *text* never
changes would never roll the deployment when a new commit is pushed.

Sourcing the chart from the PR's head commit means chart changes in the PR are
previewed too — a PR that edits `helm/accord` tests itself.

Teardown is generator-driven. When the PR stops matching (label removed, PR
closed or merged) it leaves the generator output, the `Application` is deleted,
and because `preserveResourcesOnDeletion: false` the deletion cascades through
the namespace. Nothing to clean up by hand.

Preview environments are self-contained: the chart's preview mode runs its own
throwaway pgvector Postgres on `emptyDir` and seeds it, so they need none of
`ac-postgres`, `ac-redis`, `ac-rustfs` or Temporal.
