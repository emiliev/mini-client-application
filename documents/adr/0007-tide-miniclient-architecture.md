# ADR-0007: Adopt Tide's Project Miniclient ("Lego") architecture and stack

- **Status:** Accepted
- **Date:** 2026-11-23
- **Deciders:** Product Owner (architecture and stack, Q-006), Tech Lead (mapping and deviations)
- **Related:** Q-006, T-0013, [plan 01](../plan/01-architecture-and-modules.md), [research](../research/tide-miniclient/), ADR-0005, ADR-0008

## Context
The PO chose Tide's *Project Miniclient* architecture (six Medium articles) and its stack for an enterprise Marvel app with 100+ modules. Tide's tutorial is itself a Marvel app, but it uses the real Marvel API, which is gone (F-0003), and it doesn't cover l10n, goldens, CI or cross-feature navigation.

## Decision
- **Three layers:**
  - `utility/` may depend on utilities only.
  - `feature/` may depend on utilities only; **never feature → feature**.
  - `app/` may depend on anything.

  Every module is a local package that exposes a barrel. Layering is enforced by Bazel visibility and `DartImportCheck`.
- **Stack as in the articles:**
  - state: flutter_bloc with freezed states and sealed events
  - DI: get_it + injectable behind per-package `mc_di` initializers
  - networking: dio + retrofit + json_serializable
  - a `Result` type in `mc_prelude`
  - intra-feature navigation: `mc_feature_flow` over flow_builder (the PO's "feature flow")
  - testing: mocktail + bdd_widget_test
  - scaffolding: mason
- **Our equivalents:** `mc_` package prefix in place of `tide_`; the data layer is `mc_mocked_backend` (a Dio adapter engine) plus per-domain `mc_fixtures_<domain>` packages.
- **Catalogue at S2:** 169 modules, as listed in plan 01.
- **Recorded deviations**, each justified in [plan 01 §2](../plan/01-architecture-and-modules.md) and summarised as R4 to R6, R13 and R15 to R17 (revised in the 2026-11-23 fix pass) in the [plan README](../plan/README.md#4-conflict-resolutions-tl-decisions):
  - go_router typed routes for cross-feature navigation
  - per-package gen-l10n
  - a console monitoring sink instead of Firebase
  - the barrel also exports navigator interfaces and flow arg/result types (nothing else, checked)
  - an app layer split into `app_core`, 7 wirings and 9 apps (including sandboxes)
  - feature tests: BDD + contract + l10n + golden, no solitary feature unit tests (Tide's own rule)
  - no dart-defines or flavours in debug: a Bazel-selected config asset per environment
  - the codegen purity rule (route targets; Flutter-free bloc imports; monitoring's Flutter hooks in `app_core`)
  - freezed 4's `sealed` modifier only: private cases and `state.when` are kept
  - per-flow DI containers with generated, resolve-tested root imports

## Consequences
- **Positive:** a proven, team-scalable structure; a realistic, highly modular Bazel workload.
- **Negative:** several deviations need ongoing conformance checks (plan verification wave, T-0013-AC4).
