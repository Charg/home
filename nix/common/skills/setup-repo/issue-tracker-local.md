# Issue tracker: Local Markdown

Issues and specs for this repo live as markdown files in `.scratch/`.

## Conventions

- One feature per directory: `.scratch/<feature-slug>-<NNNNN>/`. The `<NNNNN>` is a repo-unique serial for the chunk of work — the local equivalent of a JIRA key (`INFRA-7151`). Allocate it by scanning: `ls -d .scratch/*-[0-9][0-9][0-9][0-9][0-9] 2>/dev/null | sed 's/.*-//' | sort -n | tail -1` gives the highest existing serial (directories with no numeric suffix are legacy and don't count); use one more than that, or `00001` if there is none.
- The spec is `.scratch/<feature-slug>-<NNNNN>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>-<NNNNN>/issues/<NN>-<slug>.md`, numbered from `01` — never a single combined tickets file
- Triage state is recorded as a `Status:` line near the top of each issue file (see `triage-labels.md` for the role strings)
- Comments and conversation history append to the bottom of the file under a `## Comments` heading

## When a skill says "publish to the issue tracker"

Allocate a feature key (see Conventions above), then create a new file under `.scratch/<feature-slug>-<NNNNN>/` (creating the directory if needed).

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a file with one **child** file per ticket.

- **Map**: `.scratch/<effort>-<NNNNN>/map.md` — the Notes / Decisions-so-far / Fog body. Allocate `<NNNNN>` the same way as above (scan `.scratch/`, max existing serial + 1).
- **Child ticket**: `.scratch/<effort>-<NNNNN>/issues/NN-<slug>.md`, numbered from `01`, with the question in the body. A `Type:` line records the ticket type (`research`/`prototype`/`grilling`/`task`); a `Status:` line records `claimed`/`resolved`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `resolved`.
- **Frontier**: scan `.scratch/<effort>-<NNNNN>/issues/` for files that are open, unblocked, and unclaimed; first by number wins.
- **Claim**: set `Status: claimed` and save before any work.
- **Resolve**: append the answer under an `## Answer` heading, set `Status: resolved`, then append a context pointer (gist + link) to the map's Decisions-so-far in `map.md`.
