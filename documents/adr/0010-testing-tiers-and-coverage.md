# ADR-0010: Tide testing tiers, BDD traceability and a 90 % coverage gate

- **Status:** Accepted. Supersedes the ADR-0006 §2 coverage gate (80 % domain/data) and its "UI gated by per-state widget tests" rule.
- **Date:** 2026-11-23
- **Deciders:** Tech Lead
- **Related:** [plan 05](../plan/05-testing-and-bdd.md), ADR-0006, ADR-0007

## Decision
- **Tide's two tiers:**
  - Utilities get solitary unit tests.
  - Features get sociable BDD widget tests that enter only through the flow and double only external dependencies and the backend, at the transport layer through `mc_mocked_backend`.
  - Features also get contract, l10n and golden tests. Solitary feature unit tests are allowed only for pure engines the UI can't enumerate.
- **Testing packages:** `mc_test_utils` (harness, containers, mocks, golden and a11y helpers), `mc_test_steps` (the shared Gherkin step library) and `mc_e2e_utils`.
- **AC traceability:** scenarios carry `@T-XXXX-ACn` tags, which the BDD generator appends to test names. `tool/trace_acs` joins ACs → scenarios → JUnit results. This satisfies ADR-0006 §1 automatically.
- **Coverage:** **90 % per package** over hand-written `lib/` code, aiming for 100 % (Tide). Generated code is excluded, and the app is gated by journeys instead of a percentage.
- **Bazel test targets:** one aggregated target per package and kind by default, with a per-file switch (experiment X-16 decides).

ADR-0006's other rules (fresh Verifier, evidence, anti-gaming, simulator hygiene) are unchanged.

## Consequences
- A stricter gate than ADR-0006 §2.
- Verification of generated batches relies on sampled deep audits plus mutation and chaos canaries ([plan 05 §7](../plan/05-testing-and-bdd.md)).
