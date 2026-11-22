# T-0003: Flutter project scaffold

| Field | Value |
|---|---|
| Status | Blocked (on Q-006 only) |
| Owner | crew: Engineer (worktree) |
| Branch | `fleet/T-0003-flutter-scaffold` |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | Q-006 (PO stack may set the generator, lints, monorepo layout and SDK version). Q-001, Q-002 and Q-004 are answered. |
| Related | F-0001, R-004, ADR-0004, ADR-0005 |

## Goal
Create a clean, reproducible Flutter project skeleton that every worktree builds the same way.

## Inputs already decided
| Item | Value | Source |
|---|---|---|
| Project type | Flutter **application** | Q-001 |
| Platforms | Generate **iOS + Android** folders (`--platforms=ios,android`) to keep Q-002's target; **only iOS is built and verified** for now | Q-002, Q-009 |
| Bundle id / applicationId | `com.emiliev.miniclinet` (spelling to confirm) | Q-004 |
| Dart package name | `mini_client` | TL default |
| Mock data module | separate package `mocked_backend` (built in T-0007; the scaffold only reserves the layout) | ADR-0005 |

## Scope
- **In:**
  - Pin the SDK with FVM (`fvm use <version>` → `.fvmrc`), with an ADR for the version choice.
  - Create the app with the agreed project type, platforms and identifiers, using the generator and repo layout from Q-006.
  - Lint config in `analysis_options.yaml`, following the PO stack or the TL's strict default.
  - `.gitignore` covering `.fvm/` SDK symlinks and build outputs.
  - Root `README.md` with setup and run instructions using `fvm flutter`.
- **Out:** architecture and folder structure beyond the template (T-0004); `mocked_backend` contents (T-0007); CI (T-0005).

## Acceptance criteria
- [ ] `fvm flutter --version` inside the project resolves to the pinned SDK.
- [ ] `fvm flutter analyze` reports no issues.
- [ ] `fvm flutter test` passes.
- [ ] The app builds for the iOS simulator (`fvm flutter build ios --simulator --debug`) and for device without signing (`fvm flutter build ios --debug --no-codesign`). An Android build isn't required (Q-009).
- [ ] Bundle id / applicationId is `com.emiliev.miniclinet` on both platforms (or the corrected value from Q-004).
- [ ] ADR for SDK version & pinning is Accepted.
- [ ] README explains setup from a fresh clone.

## Plan
1. When Q-006 arrives, the TL fixes the generator, layout and SDK version and drafts the ADR.
2. Dispatch an Engineer in a worktree with the brief from the protocol.
3. Review, verify, integrate (ADR-0004).

## Log
- 2026-11-22: Created. Blocked on Q-001 and Q-002.
- 2026-11-22: Q-001, Q-002 and Q-004 answered. Now waiting only on the PO stack (Q-006), which arrives next.

## Outcome
_Pending._
