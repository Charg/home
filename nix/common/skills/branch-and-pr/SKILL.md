---
name: branch-and-pr
description: >-
  Git branch-and-PR workflow. Use when starting new work ("let's start on X",
  "create a branch for this") or when work is ready for review ("this is
  ready", "raise a PR", "raise a PR and auto-merge it"). Encodes this repo's
  conventions: branch naming, semantic commits/PR titles, and opt-in
  auto-merge.
---

# Branch and PR workflow

Two independent phases - figure out which applies from context.

Use semantic-commit format (`type: description`, imperative, lowercase after
the colon) for every commit message and PR title - same `type` list as branch
naming. E.g. `fix: null-pointer on checkout`, not `Fix null pointer`.

## Starting work

1. `git status` - if dirty, ask whether to stash/commit/carry changes over
   before switching. Then sync the default branch and branch off it.
2. Name the branch `type/kebab-case-description` (`feat`, `fix`, `chore`,
   `docs`, `refactor`, `test`, `perf` + 3–5 word summary), e.g.
   `fix/checkout-empty-cart-crash`. If the type or topic is ambiguous, propose
   a name and confirm rather than guessing.
3. `git switch -c <name>`.

## Opening a PR

1. Push the branch (`git push -u origin HEAD`).
2. Draft title + body from `git log`/`git diff` against the default branch -
   don't invent scope not in the commits. Title uses semantic-commit format.
   Report test status honestly.
3. Show the draft and wait for approval before creating anything (publishing
   is a one-way door).
4. Create a label if it does not exist:
   `gh label create "🤖 agent" --description "Agent Authored" --color #C4C4C4`
5. `gh pr create --label "🤖 agent" --base main --title "..." --body-file <path>` -
   add `--draft` if the user requests it should be a draft PR.
6. Auto-merge: off by default. Only enable it when the user explicitly asks
   for it for this PR (a request for an earlier PR does not carry over).
   - It cannot be combined with `--draft`; if both are asked for, say so and
     ask which they want.
   - `gh pr merge --auto --squash <url>` (use `--rebase` or `--merge` if the
     repo doesn't allow squash).
7. Return the PR URL, and say whether auto-merge is enabled.
