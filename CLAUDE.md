# mini-client — Agent Instructions

This repo is run as a **fleet**: a Tech Lead session orchestrates crew-member agents; the Product Owner (Emil) sets direction. All project knowledge lives in [`documents/`](documents/README.md).

## Every session, before doing anything
1. Read `documents/STATUS.md`, then the latest file in `documents/journal/`.
2. If you were dispatched for a task, read `documents/tasks/T-XXXX-*.md` and every ADR / finding it links.
3. Follow `documents/fleet/protocol.md`.

## Documentation rules (non-negotiable)
- If it isn't in `documents/`, it didn't happen. Ship doc updates in the same commit as the work they describe.
- A decision that is costly to reverse → ADR in `documents/adr/` (template: `documents/templates/adr.md`).
- Anything learned the hard way (gotcha, bug root cause, spike result, benchmark) → finding in `documents/findings/`.
- Work discovered but not done → `documents/pending-work.md`. A question only the Product Owner can answer → `documents/open-questions.md`.
- Crew members edit only **their own task file** plus **new** findings / ADR drafts. `STATUS.md`, `tasks/BOARD.md`, `journal/`, `fleet/roster.md` and all index files are owned by the Tech Lead (prevents merge conflicts between parallel crew).

## Toolchain
- Flutter/Dart via FVM. Always run `fvm flutter …` / `fvm dart …`. The bare `flutter` alias only exists in interactive zsh (see F-0001).

## Git
- One branch per task: `fleet/T-XXXX-<slug>`. Never commit to `main` directly; the Tech Lead integrates.
- Never use bare `git stash` / `git stash pop` — the stash is shared across worktrees. Use a WIP commit instead.
- Commit messages: `T-XXXX: <imperative summary>`.
