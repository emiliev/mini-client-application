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

## Verification (ADR-0006 as amended by ADR-0015, PO 2026-11-27)
- Every acceptance criterion `T-XXXX-ACn` needs a test whose name contains that ID, or a screenshot checkpoint if it's purely visual. Every test cited in a handoff must exist.
- Engineers run the gates (and the e2e script for feature tasks) before handing off.
- **Verification = it compiles and the tests pass.** The TL reviews the diff (`/code-review`), sends back one fix round, then runs the merge gates on the merge result: build, `test --lockfile_mode=error //...`, lint, `mc_arch_check`, `rules_fork.sh check`, the format gate, and a 20-run uncached flake check on new targets. Green means merge. There is no separate Verifier agent; the TL calls one only for the exceptions listed in ADR-0015.
- Never delete, skip or weaken tests, or add `// ignore:`, without saying so in the handoff. Never retry a flaky test until it passes; root-cause it.
- E2E agents create their own simulator (`mc-<task>-<role>`) and always delete it. Never touch the shared simulators.
- Evidence (gate logs, e2e logs and screenshots of at most 1200 px) goes in `documents/evidence/T-XXXX/`.

## Toolchain
- **iOS first:** Android is deferred by the PO (Q-009). Don't build or verify Android unless a task says so.
- Flutter/Dart via FVM. Always run `fvm flutter …` / `fvm dart …`. The bare `flutter` alias only exists in interactive zsh (see F-0001).

## Git
- Remote: `origin` → https://github.com/emiliev/mini-client-application (private, HTTPS with keychain auth; no SSH, no `gh` login). See F-0002.
- Only the Tech Lead pushes. Push non-interactively with `GIT_TERMINAL_PROMPT=0 git push …`.
- One branch per task: `fleet/T-XXXX-<slug>`, created from `origin/main`. Crew commit there and never push.
- Integration (ADR-0004): the TL reviews, runs `git merge --no-ff fleet/T-XXXX-<slug>` on its branch (which tracks `origin/main`), runs the gates, then `git push origin HEAD:main`. Never force-push `main`.
- Never use bare `git stash` / `git stash pop` — the stash is shared across worktrees. Use a WIP commit instead.
- Commit messages: `T-XXXX: <imperative summary>`.
