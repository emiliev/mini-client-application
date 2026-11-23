# ADR-0009: Exemplar-first code generation and the LOC metric

- **Status:** Accepted (the LOC metric is pending PO confirmation, Q-010)
- **Date:** 2026-11-23
- **Deciders:** Tech Lead
- **Related:** [plan 02](../plan/02-generation-and-scale.md), [plan 01 §6 to §8](../plan/01-architecture-and-modules.md), Q-010

## Decision
- **Exemplar-first.** Hand-build one verified reference module per archetype. `tool/mcgen` then generates the rest from committed per-module specs, with seeded, measured realism variation. Each exemplar is mcgen's golden test.
- **Ownership.** Generated modules have ownership modes (`managed` / `mixed` / `ejected`), keep regions and a drift manifest, so regeneration never clobbers human work.
- **LOC metric.** The metric counts **committed first-party `.dart`**, which includes scaffolded source and excludes build-time generated files. `tool/loc` reports `hand`, `scaffold`, `test`, `generated` and `tooling` separately, with a hand share of at least 5 %.
- **Scale ladder.** S0 (15 packages, about 35k LOC) → S1 (50, 150k) → **S2 (169, about 634k)** → S3 (about 190, about 1M) → S4 (synthetic, out of tree, 5M and 10M), each with LOC, build, test and oracle gates.
- **Edit corpus.** `tool/edits` provides 17 deterministic edits with expected rebuilt sets; that's the incremental-build oracle for [plan 04](../plan/04-profiling-optimization-upstream.md).

## Consequences
- **Positive:** 600k to 1M realistic lines are reachable in about 44 crew tasks instead of hundreds, and the generator doubles as the S4 synthesiser.
- **Negative:** realism has to be policed (realism gates, sampled audits). A scaffold-heavy codebase must be labelled honestly in every report.
