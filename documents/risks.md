# Risk Register

_Owned by Tech Lead. Review at each phase change._ Likelihood and impact: Low / Med / High.

| ID | Risk | Likelihood | Impact | Mitigation | Status |
|---|---|---|---|---|---|
| R-001 | Scope is undefined, so early technical choices may need rework | High | Med | No architecture or scaffold work before Q-001 to Q-003 are answered; keep decisions in ADRs so they are cheap to revisit | Open |
| R-002 | Context loss between agent sessions leads to repeated or contradictory work | High | High | ADR-0002: docs as source of truth, STATUS plus journal read at every session start, CLAUDE.md enforces it | Mitigated |
| R-003 | Parallel crew cause merge conflicts in shared docs or code | Med | Med | ADR-0003: one task per worktree and branch; only the TL edits shared docs; parallelise only tasks with no file overlap | Mitigated |
| R-004 | Toolchain drift: different SDK per worktree, or the `flutter` alias missing in agent shells | Med | Med | Always `fvm flutter`; pin with `.fvmrc` in T-0003 (F-0001) | Open (closes with T-0003) |
