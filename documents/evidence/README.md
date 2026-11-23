# Verification Evidence

One folder per task, `T-XXXX/`, written by the **Verifier** ([ADR-0006](../adr/0006-verification-strategy.md)):

- `verification-report.md`: PASS / FAIL per acceptance criterion, gates re-run, test-integrity audit ([template](../templates/verification-report.md))
- `*.png`: screenshots captured at e2e checkpoints, no taller than 1200 px (`sips -Z 1200` only when larger; it also enlarges small images)

The task's Outcome section links its evidence folder. Screenshots are the one sanctioned exception to "no binary images" in `documents/` (ADR-0002 is about diagrams).

## Index
| Task | Verdict | Report |
|---|---|---|
| [T-0009](T-0009/verification-report.md) | PASS (TL spot-check) | Verification pipeline spike: 4 screenshots |
| [T-0012](T-0012/verification-report.md) | PASS (fresh Verifier) | Simulator e2e runner: engineer and verifier evidence, 13-test suite |
