# Risk Register

_Owned by Tech Lead. Review at each phase change._ Likelihood and impact: Low / Med / High.

| ID | Risk | Likelihood | Impact | Mitigation | Status |
|---|---|---|---|---|---|
| R-001 | Scope not fully defined, so early technical choices may need rework | Med (was High: product and platforms are now set; MVP features proposed, Q-008) | Med | No architecture or scaffold work before the PO stack (Q-006); decisions in ADRs so they're cheap to revisit | Open |
| R-002 | Context loss between agent sessions leads to repeated or contradictory work | High | High | ADR-0002: docs as source of truth, STATUS plus journal read at every session start, CLAUDE.md enforces it | Mitigated |
| R-003 | Parallel crew cause merge conflicts in shared docs or code | Med | Med | ADR-0003: one task per worktree and branch; only the TL edits shared docs; parallelise only tasks with no file overlap | Mitigated |
| R-004 | Toolchain drift: different SDK per worktree, or the `flutter` alias missing in agent shells | Med | Med | Always `fvm flutter`; pin with `.fvmrc` in T-0003 (F-0001) | Open (closes with T-0003) |
| R-005 | **Marvel IP:** a public store release of a Marvel-branded app without a licence gets rejected (Apple 5.2, Google IP policy) or draws a takedown | High (if listed publicly) | High (blocks public release) | Q-007 raised. No copyrighted Marvel artwork bundled (placeholders); no Marvel marks in app name or icon; distribute privately until licensing is resolved | Dormant (no store release planned, Q-007) |
| R-006 | A mock-only backend hides real-world problems (latency, failures, pagination), so the app breaks on a real backend | Med | Med | ADR-0005: the mock simulates latency, failures and pagination; features depend only on the data-source interface | Mitigated (by design) |
| R-007 | A bundle id typo (`miniclinet`) is permanent after the first store release | Med | Med | Q-004 asks for confirmation; trivial to change before T-0003 / first release | Closed 2026-11-23 (bundle id `com.emiliev.miniclient`) |
| R-008 | E2E tests turn flaky or slow, eroding trust in the merge gate | Med | Med | ADR-0006: deterministic mock (zero latency, fixed data), a dedicated simulator per run, no retry-until-green (flakes become findings), a fast smoke journey per task with the full journey only at phase exit | Open |
| R-009 | Android regressions slip through, since Android verification is deferred | Med | High | PO decision (Q-009): iOS first. Shared Dart code stays covered by L0 to L3; minimise platform-specific code; re-enable Android verification before any Android release (P-014) | Accepted (PO) |
| R-010 | Crew "verify" their own work, or weaken tests to pass | Med | High | ADR-0006: a fresh Verifier agent, test audit against ACs, anti-gaming rules, TL re-verifies the merge result | Mitigated (by process) |
