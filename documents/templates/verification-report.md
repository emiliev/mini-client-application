# Verification report — T-XXXX: <Title>

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** YYYY-MM-DD
- **Branch / commit verified:** `fleet/T-XXXX-<slug>` @ `<sha>`
- **Simulator:** `mc-T-XXXX-verifier`, iPhone 17 Pro, iOS 26.2 (created and deleted by the Verifier)
- **Verdict:** PASS | FAIL

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| L0 Format | `fvm dart format --output=none --set-exit-if-changed .` | |
| L0 Analyze | `fvm flutter analyze` | |
| L1–L3 Tests | `fvm flutter test --coverage` | _N passed, M failed_ |
| Coverage | domain / data / mocked_backend line % | _xx % (≥ 80 %)_ |
| L4 E2E | `<e2e command>` | |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-XXXX-AC1 | | | yes / no, with why | PASS / FAIL |

## Test-integrity audit
- Tests deleted, skipped or weakened: _none / list_
- Lint suppressions added: _none / list, with justification_
- Golden files updated: _none / list, with before and after_

## Visual acceptance (UI tasks)
| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| | `documents/evidence/T-XXXX/<name>.png` | | |

## Issues found
1. _(severity) description, plus how to reproduce_

## Notes for the Tech Lead
