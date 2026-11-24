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
| [T-0015](T-0015/verification-report.md) | PASS (fresh Verifier, re-verified after fixes) | `tool/loc`: hand-counted fixtures, CLI strict check |
| [T-0016](T-0016/verification-report.md) | PASS (re-verified after first FAIL) | Perf harness: fresh-clone suite, AC7 5/5 under load |
| [T-0014](T-0014/verification-report.md) | PASS (re-verified after fixes) | Toolchain: sim app screenshots, outline cutoff, cfgdup counts, codegen byte-identity |
| [T-0017](T-0017/verification-report.md) | PASS (re-verified after first FAIL) | Arch guard violation fixtures, Result/DI semantics |
| [T-0019](T-0019/verification-report.md) | PASS (re-verified after first FAIL) | Design system: real-font goldens across 4 themes and 2 text scales, semantics |
| [T-0018](T-0018/verification-report.md) | PASS (re-verified after review fixes) | Mocked backend: black-box checks, mutation checks |
| [T-0020](T-0020/verification-report.md) | PASS (re-verified after review fixes) | Config env flag, monitoring sinks, event bus, atomic storage |
| [T-0023](T-0023/verification-report.md) | PASS (re-verified after FAIL) | API client: failure mapping, retries, Flutter-free closure check |
| [T-0022](T-0022/verification-report.md) | PASS (3rd round) | Feature flow: edge-swipe state and content probes, mutation checks |
| [T-0021](T-0021/verification-report.md) | PASS (re-verified after review fixes) | **First app screens**: home in Inter, deep-link detail, `openurl` dialog (iOS 26.2 and 18.2) |
| [T-0025](T-0025/verification-report.md) | PASS (re-verified after review fixes) | l10n: de/en/en_XA strings, money and dates, ARB gate, gen-l10n parity |
| [T-0024](T-0024/verification-report.md) | PASS (3rd round) | Patch queue: real-pin round trip, stale-patch drift, export guards |
| [T-0026](T-0026/verification-report.md) | PASS (re-verified after review fixes) | Test harness: isolation probes, unmatched requests, fail/hold/release |
| [T-0027](T-0027/verification-report.md) | PASS (re-verified after FAIL) | retrofit shim: byte identity incl. cross-package summaries, rerun scope, masked-build negative |
