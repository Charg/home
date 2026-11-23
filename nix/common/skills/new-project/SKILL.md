---
name: new-project
description: >-
  Create a new project from the Charg/template Copier template: nix flake dev
  shell, justfile, lint, prek hooks, AGENTS.md, and optionally a GitHub repo with
  CI, Renovate and auto-merge.
disable-model-invocation: true
---

# New project from the template

Every new project starts from `gh:Charg/template`. Don't hand-write a flake,
justfile or CI. Copier's prompts need a TTY, so collect the answers here and
render with `--defaults --data`.

## 1. Gather answers

From the request, draft `project_name` (must match `^[a-z0-9][a-z0-9._-]*$`), a
one-line `description`, and the path (default `~/code/<project_name>`; it must
not exist or must be empty). Then make **one** AskUserQuestion call, putting the
inferred or recommended option first in each question:

1. **Flavours** (multiSelect): `go`, `python`, `container-images`, `helm-charts`.
   Pre-describe the inferred set: Go code → `go`; Python → `python`; builds an
   image → `container-images`; charts in this repo → `helm-charts`.
2. **Hosting**: GitHub private (recommended) / GitHub public / offline (no
   `.github/`, commits to main).
3. **nixpkgs**: `nixos-26.05` (recommended) / `nixos-unstable`. It must be
   26.05 if `helm-charts` is picked.
4. **Name and description**: show the drafts as the first option; "Other" lets
   them edit.

Ask for the GitHub owner only if it's unclear; default to `Charg`. Flavours
are toolchain layers only. Never add repo layouts or release pipelines.

## 2. Render

Clone `Charg/template` to `~/code/template` if it's missing. Pull it when it's
clean and on main (`git -C ~/code/template pull --ff-only`). Rendering always
comes from `gh:Charg/template`; the checkout only supplies the scripts and
`copier`.

```sh
cd ~/code/template && nix develop -c just new <path> --defaults \
  --data project_name=<name> \
  --data 'description=<description>' \
  --data github=<true|false> \
  --data nixpkgs_channel=<channel> \
  --data 'flavours=[go,container-images]'     # [] for none
```

This renders the files, runs `git init`, locks the flake, installs prek hooks and
runs `just lint`. If lint fails, show the output. Fix the new project if that's
where the problem is. If the template is wrong, stop and say so rather than
working around it.

## 3. Fill in the project-owned parts

- `AGENTS.md`: write `## Project` below the TEMPLATE markers (purpose, intended
  layout, decisions so far). Never edit between the markers.
- `README.md`: an intro paragraph beyond the description, if there's more to
  say.

## 4. Commit, then GitHub

Offline projects: `git add -A && git commit -m "feat: init project from template"`
on main, then go to step 5.

GitHub projects: these steps create things outside the machine and auto mode
won't ask about them. Show this exact list and wait for one explicit yes:

```sh
gh actions-lock --no-narrow    # always --no-narrow; without it zizmor rejects the lock
git add -A && git commit -m "feat: init project from template"
gh repo create <owner>/<name> --<private|public> --source . --push
gh repo edit <owner>/<name> --enable-auto-merge --enable-squash-merge --delete-branch-on-merge
gh api -X POST repos/<owner>/<name>/rulesets --input <this skill's dir>/ruleset.json
```

If `actions-lock` fails because the repo isn't on GitHub yet, commit without it,
push, then run it and commit the lock as `ci: add actions.lock`.

## 5. Report

The path, flavours and repo URL, plus anything left for the user. Renovate
needs its GitHub app given access to the new repo, so check with the user
rather than assuming. Mention `just update <path>` from `~/code/template` for
future template changes, and `/repo-setup` if they'll use the ticket skills.
