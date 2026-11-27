# ADR-0015: Lean verification: no feature goldens, targeted mutations, correctness-only Verifiers

- **Status:** Accepted (PO direction, 2026-11-27)
- **Date:** 2026-11-27
- **Deciders:** Product Owner (direction), Tech Lead (rules)
- **Supersedes in part:** ADR-0006 (verification strategy: goldens, Verifier scope), ADR-0011 (Verifier scope per tier), plan 01 R6 / D-30 (feature test kinds)
- **Related:** T-0056 (FAIL round cost), T-0063 and T-0064 (in flight when this was adopted), plan 02 §7.3 (per-batch verification)

## Context
Verification has been thorough, and also the slowest part of every task:
- Engineers ran 50 to 100+ mutants per task, with runs that took hours and timed out.
- Feature goldens covered 4 themes × 2 scales and needed re-baselining on every visual change.
- Verifiers re-derived everything: their own probes, their own mutants, coverage parsers and full diff audits. An Opus exemplar pass cost 250k to 330k tokens.

Two Opus exemplars running in parallel used up the 5-hour usage window twice in one day. The PO asked to "optimise the process and get there faster": stop covering features with golden tests, and have Verifiers only make sure the implementation is correct.

The PO also answered two follow-up questions:
- Features keep BDD as their main tests. Plain unit tests are allowed for pure logic.
- Mutations are capped at about 15 targeted mutants.

## Decision
1. **No golden tests in features** (`feature/**`). Visual acceptance criteria become widget tests:
   - the expected strings are present (de, en_XA);
   - no overflow or layout errors at 1× and 2× text scale;
   - theme and density effects are checked by reading colours, brightness or sizes.

   Custom painters in features use recording-canvas tests (F-0059). E2E screenshots stay as evidence for e2e ACs.
   - Existing feature goldens stay until their package is next touched. They may then be deleted, and the handoff says so.
   - **DS kits (`utility/mc_ds_*`) keep their goldens.** They are the visual components, and nothing else checks their pixels.
2. **Feature tests are BDD-first.**
   - BDD scenarios through the flow stay the main tests, tagged with AC IDs.
   - Contract tests stay.
   - **Plain unit tests are now allowed for pure logic inside a feature**: engines, mappers, rules, formatters. This relaxes R6 / D-30.
   - Widget and bloc behaviour is still tested through BDD.
3. **Mutations are capped at about 15 targeted mutants per task.**
   - Engineers pick them where a silent test gap would hurt: races and the session epoch, money, scoring, auth and pins, validation boundaries, persistence.
   - The mutation script rules stay: it refuses a dirty tree, sets the trap before the first edit, and counts BROKEN separately from KILLED.
   - No full-package mutation sweeps.
4. **Verifiers check correctness only.** For each AC the Verifier:
   - finds the cited test, reads it, judges that it really asserts the AC, and runs it;
   - re-runs the gates;
   - runs the e2e for e2e ACs;
   - probes only where an AC or a review finding points at real risk;
   - re-runs **up to 5** of the engineer's mutants to confirm that the tests bite.

   Verifiers **no longer** do the following by default:
   - write their own mutant sets;
   - write their own coverage parsers (the gates report is enough);
   - re-derive whole subsystems;
   - audit the full diff.

   The test-integrity check stays: deleted, skipped or weakened tests and suppressions, from a diff of the test files only. So does the rule that every cited test exists.
5. **Unchanged:**
   - review-first (`/code-review` before the Verifier);
   - a fresh Verifier, and nothing merges without a PASS;
   - the TL's merge gates;
   - the DoD flake check (50 runs on storage, timer, stream and race tests);
   - the model tiers of ADR-0011, except where this ADR narrows the Verifier's scope.

## Consequences
- **Faster.** Tasks finish sooner, with fewer hours spent on mutation runs, and Verifier passes should cost roughly half. Fewer golden re-baselines.
- **Weaker visual safety net in features.** A pure styling regression, such as a colour or spacing that drifts without overflowing, can slip through. DS goldens still catch component-level changes, and e2e screenshots are viewed by Verifiers.
- **Fewer mutants means less proof that tests bite outside the risky spots.** Review-first and the Verifier's 5 confirmation mutants mitigate this.
- **The bricks (P1-24) and `mcgen` (P2) templates follow this ADR.** Generated features carry no goldens and about 15 targeted mutants per batch. Plan 02 §7.3 is to be read with this ADR.
