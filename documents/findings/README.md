# Findings

A finding is knowledge we earned and don't want to earn twice: environment gotchas, bug root causes, spike results, benchmarks, library behaviour, dead ends.

**Process:** copy [../templates/finding.md](../templates/finding.md) to `F-XXXX-<slug>.md` using the next free number. Crew may create findings freely; the Tech Lead adds them to the index below.

## Index
| ID | Title | Type | Date | Impact |
|---|---|---|---|---|
| [F-0001](F-0001-environment-survey.md) | Development environment survey | Environment | 2026-11-22 | Agents must use `fvm flutter`; no git remote yet (superseded by F-0002) |
| [F-0002](F-0002-github-remote-access.md) | GitHub remote access | Environment | 2026-11-22 | `origin` over HTTPS via keychain; no SSH, no `gh`, so no CLI PRs |
| [F-0003](F-0003-marvel-api-unavailable.md) | The official Marvel API is effectively unavailable | Spike | 2026-11-22 | `mocked_backend` contract is our own design; no real-API swap target |
| [F-0004](F-0004-ios-verification-pipeline.md) | The iOS verification pipeline works end to end on this Mac | Spike | 2026-11-22 | All ADR-0006 layers proven; e2e 41 s cold / 13 s warm; goldens need real fonts; create simulators, never clone |
| [F-0005](F-0005-bash-background-jobs-ignore-sigint.md) | Bash background jobs ignore SIGINT; traps wait for foreground children | Lesson | 2026-11-23 | Use `cmd & wait $!`, process groups, and ignore INT/TERM during teardown |
| [F-0008](F-0008-bazel-9-2-tooling-gaps.md) | Bazel 9.2 tooling gaps: no `analyze-profile`, no `--verbose_explanations`, concatenated JSON exec log | Environment | 2026-11-23 | Perf ingestion and the AC5 reference changed; plan 04 §6.3 needs a refresh (P-020) |
