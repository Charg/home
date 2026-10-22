# Worker prompt

The ticket-worker fills in the `<placeholders>` and passes the **Implement** section to a new subagent, or the **Fix** section to a resumed or replacement one.

## Implement

```text
Implement GitHub issue #<n> on <owner>/<repo> ("<title>"). Read it in full with `gh issue view <n> --comments`, and its parent issue if it has one. Before writing code, read the repo's agent instructions (AGENTS.md / CLAUDE.md), CONTEXT.md and any ADRs in the area you touch, and follow them.

Work on branch `<branch>` in your worktree, branched from the latest `origin/<default>`.

<coordination notes: other tickets in flight and the files they touch, or "none">

How to work:
- Use /tdd at sensible seams. Run the repo's tests, lint and format checks (see its justfile / docs) and get them green before opening the PR.
- Run every shell command as one plain command per Bash call: no `&&` chains and no `cd x &&` prefix (use `git -C <dir>`). Permission rules only match plain commands.
- Commit with semantic messages (`type: description`). Never force-push, never push to <default>.

When the work is green:
1. `git push -u origin HEAD`
2. `gh pr create --base <default> --label "🤖 agent" --title "<semantic title>" --body-file <file>`. Open it ready for review, not draft. The body says what changed, how it was tested, any judgement calls, and ends with `Closes #<n>`. You have standing approval to open it without showing a draft first.
3. <either: "Enable auto-merge: `gh pr merge --auto --squash <pr-url>`. GitHub merges it once the required checks pass." or: "Do not enable auto-merge.">

Do not wait for CI and do not merge the PR yourself.

Final report: the PR URL (or why there isn't one), a short summary of what you built, local test results, judgement calls, and anything in the issue you did not do.
```

## Fix

```text
Your PR <pr-url> for issue #<n> needs another pass: <failing checks with run URLs | merge conflict with <default>>. This is fix attempt <k>.

Work in your worktree (<worktree path>), or if it's gone, a fresh worktree on branch `<branch>`.

1. `git -C <dir> fetch origin`, then bring the branch up to date with `git -C <dir> merge origin/<branch>` (the branch may have been updated on GitHub), then `git -C <dir> merge origin/<default>`. Merge rather than rebase so no force-push is needed; the PR is squash-merged, so <default> stays linear.
2. Resolve conflicts keeping both sides' intent. For failing checks, read the logs with `gh run view <run-id> --log-failed` and fix the cause, not the test.
3. Re-run the tests and lint locally until green, commit, and `git -C <dir> push`.

Same rules as before: one plain command per Bash call, never force-push, never merge the PR yourself. Auto-merge stays enabled across pushes.

Final report: what was wrong, what you changed, and local test results.
```
