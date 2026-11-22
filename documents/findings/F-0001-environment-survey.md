# F-0001: Development environment survey

- **Date:** 2026-11-22
- **Author:** Tech Lead
- **Type:** Environment
- **Related:** T-0001, T-0003, R-004

## Summary
The repository is empty: one "Initial commit", no tracked files, no remote. Flutter is installed through FVM. The `flutter` command is a **zsh alias** that doesn't exist in non-interactive shells, so agents and scripts must call `fvm flutter` / `fvm dart` explicitly.

## Evidence
| Item | Observation |
|---|---|
| Repo | Main checkout `/Users/emililiev/projects/flutter/mini-client` (branch `main`). Fleet worktrees under `/Users/emililiev/orca/workspaces/mini-client/`. Single commit `ae3ec79`, no files. |
| Remote | `git remote -v` is empty, so there is no CI or PR flow yet. _Update 2026-11-22: GitHub `origin` added; see [F-0002](F-0002-github-remote-access.md)._ |
| FVM | `/opt/homebrew/bin/fvm`. Cache at `/Users/emililiev/fvm/versions`. |
| SDKs | Global: Flutter **3.41.0** / Dart **3.11.0** (stable). Also in the cache: 3.47.4 and 3.38.5, which `fvm list` shows as "Need setup". |
| `flutter` | In zsh: `flutter: aliased to fvm flutter`. In `bash -c 'type flutter'`: `not found`. |
| `dart` | Not on PATH. `fvm dart --version` → 3.11.0 works. |

## Implications / actions
- `CLAUDE.md` requires `fvm flutter` / `fvm dart`. Done in T-0001.
- T-0003 must add `.fvmrc` so every worktree resolves the same SDK, whatever the global version is.
- CI (T-0005) waits on a remote (Q-005).
