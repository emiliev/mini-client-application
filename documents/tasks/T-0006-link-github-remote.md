# T-0006: Link GitHub remote

| Field | Value |
|---|---|
| Status | Done |
| Owner | Tech Lead |
| Branch | `continue-previous-work`, pushed as `fleet/T-0001-documentation-scaffold` (shares the bootstrap branch with T-0001) |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | — |
| Related | Q-005, F-0002, T-0005, P-008 |

## Goal
Connect the local repo to the PO's GitHub repository so that work is backed up, visible, and ready for CI and PRs.

## Scope
- **In:** add `origin`, push `main`, push the docs branch, record access details.
- **Out:** CI (T-0005); merging docs into `main` (P-008, waits on the Q-005 merge policy).

## Acceptance criteria
- [x] `git remote -v` shows `origin` → `https://github.com/emiliev/mini-client-application.git`.
- [x] `main` pushed and tracking `origin/main`.
- [x] Docs branch pushed to `origin`.
- [x] Access method and limitations recorded (F-0002).

## Log
- 2026-11-22: PO provided the repo URL. Probed access: HTTPS works through the keychain, SSH has no key, `gh` is not logged in, and the repo is private and was empty. Added `origin`, pushed `main` (`ae3ec79`), and pushed the docs branch as `fleet/T-0001-documentation-scaffold`.

## Outcome
- **Changed:** git config (`remote.origin`, `branch.main` upstream), shared by all worktrees. Docs updated in this commit.
- **Verified:** `git ls-remote origin` lists `refs/heads/main` at `ae3ec79` and the docs branch.
- **Findings:** F-0002.
- **Follow-ups:** P-008 (merge docs into `main`); Q-005 (merge policy, optional `gh auth login`).
