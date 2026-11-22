# Pending Work

Known work that isn't yet a scoped task: ideas, deferred items, tech debt, follow-ups from handoffs. The Tech Lead triages these into tasks on the [BOARD](tasks/BOARD.md) when they become relevant. When an item is promoted or completed, note it and keep the row.

| ID | Item | Type | Source | When relevant | Promoted to / Done |
|---|---|---|---|---|---|
| P-001 | Testing strategy ADR: unit / widget / golden / integration, coverage targets | Decision | T-0001 | With T-0004 (may come from the PO stack) | — |
| P-002 | Theming / design-system approach (light + dark per charter) | Decision | T-0001 | With T-0004 | — |
| P-003 | Localization (i18n): needed? which languages? | Product → PO | T-0001 | After Q-008 | — |
| P-004 | Observability: crash reporting, logging, analytics (third-party, so PO sign-off) | Decision | T-0001 | Phase 3 | — |
| P-005 | Release & distribution: signing, flavors / environments, TestFlight / Play internal testing | Feature | T-0001 | Phase 3 (gated by Q-007) | — |
| P-006 | Accessibility baseline (semantics, contrast, text scaling) | Quality | T-0001 | Phase 2 | — |
| P-007 | Dependency update policy (Dependabot, since we're on GitHub) | Tooling | T-0001 | After T-0003 | — |
| P-008 | Merge the docs branch `fleet/T-0001-documentation-scaffold` into `main` | Integration | T-0001, T-0006 | — | **Done** 2026-11-22 (ADR-0004; fast-forward, remote branch deleted) |
| P-009 | App display name and icon free of Marvel trademarks | Product → PO | Q-007, R-005 | Before the first distributable build | — |
| P-010 | Tablet / large-screen layouts (mobile-first now) | Feature | Charter non-goals | After MVP | — |
| P-011 | Placeholder imagery strategy for fixtures (generated or bundled; size budget) | Decision | ADR-0005, T-0007 | With T-0007 | — |
