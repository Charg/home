# Agent notes

## GitHub Actions

- Pin every `uses:` to a full commit SHA with a version comment.
- After adding or bumping an action, regenerate the lockfile with
  `gh actions-lock --no-narrow`. Without `--no-narrow` it rewrites SHA pins to
  tags, which zizmor's `unpinned-uses` audit rejects.
