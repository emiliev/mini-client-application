# F-0002: GitHub remote access

- **Date:** 2026-11-22
- **Author:** Tech Lead
- **Type:** Environment
- **Related:** T-0006, Q-005, T-0005, F-0001

## Summary
The project's remote is the **private** GitHub repo `emiliev/mini-client-application`, linked as `origin` over **HTTPS**. Authentication comes from the macOS keychain credential helper. SSH has no key, and the `gh` CLI is not logged in, so agents can push and pull but **cannot open PRs, comment, or read CI results** from the command line.

## Evidence
| Check | Result |
|---|---|
| `git ls-remote https://…/mini-client-application.git` | exit 0, empty: the repo existed and was empty |
| `curl https://api.github.com/repos/emiliev/mini-client-application` (no auth) | 404, so the repo is private |
| `git config credential.helper` | `osxkeychain` |
| `ssh -T git@github.com` | `Permission denied (publickey)`: no SSH key set up |
| `gh auth status` | not logged in |
| `git push -u origin main` | succeeded, so the keychain credentials have write access |

## Implications / actions
- Keep the remote URL as HTTPS. Don't switch to SSH.
- Push non-interactively with `GIT_TERMINAL_PROMPT=0 git push …`, so an auth failure errors out instead of hanging (recorded in CLAUDE.md).
- The remote lives in the shared `.git/config`, so every worktree sees `origin`.
- PR-based integration from the CLI needs `gh auth login` or `GH_TOKEN`, which is a PO action (Q-005). Until then the PO opens PRs in the GitHub UI, or the TL merges locally.
- CI on a private repo uses the account's GitHub Actions minutes. Keep the T-0005 workflows lean.

## Update 2026-11-26
- Large pushes (for example 160 golden PNGs in T-0044) fail over HTTPS with `unable to rewind rpc post data - try increasing http.postBuffer`. The TL worktree now sets `git config http.postBuffer 524288000`, and the retried push succeeded. Set it in any clone that pushes.
