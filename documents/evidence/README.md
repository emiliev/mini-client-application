# Verification Evidence

One folder per task, `T-XXXX/`, written by the **Verifier** ([ADR-0006](../adr/0006-verification-strategy.md)):

- `verification-report.md`: PASS / FAIL per acceptance criterion, gates re-run, test-integrity audit ([template](../templates/verification-report.md))
- `*.png`: screenshots captured at e2e checkpoints, downscaled to at most 1200 px (`sips -Z 1200`)

The task's Outcome section links its evidence folder. Screenshots are the one sanctioned exception to "no binary images" in `documents/` (ADR-0002 is about diagrams).

## Index
| Task | Verdict | Report |
|---|---|---|
| — | — | No verified implementation tasks yet |
