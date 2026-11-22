# T-0005: Local gate (`tool/verify.sh`) & CI

| Field | Value |
|---|---|
| Status | Blocked |
| Owner | crew: Engineer (worktree) |
| Verifier | crew: Verifier |
| Branch | `fleet/T-0005-verify-and-ci` |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | T-0003; commands from T-0009 (F-0004). Hosting is GitHub (T-0006), so CI is GitHub Actions. |
| Related | ADR-0004, ADR-0006 (L0 to L3 and the coverage gate), T-0010, Q-009 |

## Goal
One command, identical for the Engineer, the Verifier, the TL's post-merge check and CI, that runs the static and test gates from ADR-0006 and fails on any violation.

## Scope
- **In (local):** `tool/verify.sh`, which runs:
  - L0: `fvm dart format --output=none --set-exit-if-changed .` and `fvm flutter analyze` (zero issues), across every package in the workspace
  - L1 to L3: `fvm flutter test --coverage` for every package; golden tests run on macOS only
  - Coverage gate: at least 80 % line coverage for domain, data and `mocked_backend`, computed from `lcov.info` with no extra tools
  - A one-line summary per gate, and a non-zero exit on any failure
- **In (CI):** a GitHub Actions workflow on push to `main` and on `fleet/**` branches that runs `tool/verify.sh` (goldens excluded on Linux) and `fvm flutter build apk --debug`. That is the Android coverage until Q-009 is resolved. Cache the SDK and pub packages; keep jobs lean, since the repo is private and uses Actions minutes. Record the CI platform in an ADR.
- **Out:** e2e and screenshots (T-0010); release pipeline (P-005).

## Acceptance criteria
- **T-0005-AC1:** Given a clean tree, when `tool/verify.sh` runs, then every gate passes and it exits 0 with a summary.
- **T-0005-AC2:** Given an unformatted file, an analyzer warning, a failing test, or coverage under 80 % in a gated package (each introduced separately), when `tool/verify.sh` runs, then it exits non-zero and names the failed gate.
- **T-0005-AC3:** Given a push to `main`, then the GitHub Actions workflow runs `tool/verify.sh` and the Android debug build, and reports green.
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

## Outcome
_Pending._
