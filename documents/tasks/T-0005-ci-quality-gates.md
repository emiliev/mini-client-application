# T-0005: Local gate (`tool/verify.sh`) & CI

| Field | Value |
|---|---|
| Status | Superseded 2026-11-23: see [BOARD](BOARD.md#superseded-by-the-enterprise-plan-2026-11-23) |
| Owner | crew: Engineer (worktree) |
| Verifier | crew: Verifier |
| Branch | `fleet/T-0005-verify-and-ci` |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | T-0003. Commands proven by T-0009 ([F-0004](../findings/F-0004-ios-verification-pipeline.md)). Hosting is GitHub (T-0006), so CI is GitHub Actions. |
| Related | ADR-0004, ADR-0006 (L0 to L3 and the coverage gate), T-0010, Q-009 |

## Goal
One command, identical for the Engineer, the Verifier, the TL's post-merge check and CI, that runs the static and test gates from ADR-0006 and fails on any violation.

## Scope
- **In (local):** `tool/verify.sh`, which runs:
  - L0: `fvm dart format --output=none --set-exit-if-changed .` and `fvm flutter analyze` (zero issues), across every package in the workspace
  - L1 to L3: `rm -rf test/failures`, then `fvm flutter test --coverage` for every package. Golden tests run on macOS only, **load real fonts and set the iOS platform** in `test/flutter_test_config.dart`; the default Ahem font renders text as boxes (F-0004)
  - Coverage gate: at least 80 % line coverage for domain, data and `mocked_backend`, computed from `lcov.info` with no extra tools
  - A one-line summary per gate, and a non-zero exit on any failure
- **In (CI):** a GitHub Actions workflow on push to `main` and on `fleet/**` branches that runs `tool/verify.sh` on a Linux runner (goldens excluded there, since they're macOS-only). No Android build: the PO deferred Android (Q-009). iOS e2e stays local with the Verifier, because macOS runners use about 10× the minutes. Cache the SDK and pub packages; keep jobs lean, since the repo is private and uses Actions minutes. Record the CI platform in an ADR.
- **Out:** e2e and screenshots (T-0010); release pipeline (P-005).

## Acceptance criteria
- **T-0005-AC1:** Given a clean tree, when `tool/verify.sh` runs, then every gate passes and it exits 0 with a summary.
- **T-0005-AC2:** Given an unformatted file, an analyzer warning, a failing test, or coverage under 80 % in a gated package (each introduced separately), when `tool/verify.sh` runs, then it exits non-zero and names the failed gate.
- **T-0005-AC3:** Given a push to `main`, then the GitHub Actions workflow runs `tool/verify.sh` and reports green.
- **T-0005-AC4:** The Definition of Done in `fleet/protocol.md` references `tool/verify.sh`.

## Verification plan
| AC | Layer | Test / checkpoint | Status |
|---|---|---|---|
| T-0005-AC1 | script | Verifier runs it on a clean tree | ☐ |
| T-0005-AC2 | script | Verifier injects each failure in a scratch commit | ☐ |
| T-0005-AC3 | CI | Workflow run on `main` is green (TL checks, or the PO checks if `gh` isn't authenticated) | ☐ |
| T-0005-AC4 | doc | Protocol diff | ☐ |

## Log
- 2026-11-22: Created. Blocked on T-0003 and Q-005.
- 2026-11-22: The hosting part of Q-005 is answered (GitHub, T-0006). Now blocked only on T-0003.
- 2026-11-22: Rescoped by ADR-0006: `tool/verify.sh` is the single local gate (L0 to L3 plus coverage); e2e moved to T-0010; CI builds an Android APK as interim Android coverage (Q-009).
- 2026-11-22: T-0009 done. Commands come from F-0004. Golden real-font setup added to scope.
- 2026-11-22: The PO deferred Android (Q-009), so the CI Android APK build was dropped from scope.

## Superseded
2026-11-23: replaced by the enterprise plan. See [plan/README.md §6](../plan/README.md#6-superseded-and-rescoped-tasks).

## Outcome
_Pending._
