# ADR-0008: Build with Bazel using ai_rules_dart / ai_rules_flutter

- **Status:** Accepted
- **Date:** 2026-11-23
- **Deciders:** Product Owner (Bazel and these rules, Q-006), Tech Lead (pins and mechanics)
- **Related:** [plan 03](../plan/03-bazel-integration.md), [research](../research/bazel-rules/), ADR-0007, ADR-0009

## Decision
- **Pins:**
  - Bazel 9.3.0 (bzlmod), through a `tool/bazelw` wrapper
  - `ai_rules_dart` `e7163aab8f…` (v0.28.3)
  - `ai_rules_flutter` `876e263d65…` (v0.30.2)
  - Flutter 3.47.7, with the same version in `.fvmrc`
  - rules_apple 5.2.0, rules_swift 4.1.2, apple_support 2.9.1
- **Bazel is the source of truth.** Build-time generated code is never committed. `tool/ide_sync` copies generated outputs into the tree (git-ignored) for the IDE and for `fvm flutter` baselines.
- **Patches to the rules** live in an in-repo patch queue (`third_party/rules_patches/`) applied via `git_override(patches=…)`, one patch per upstream PR draft in `documents/upstream/`. Real forks come once GitHub access exists (Q-013).
- **Dependencies:** one pub workspace; the root lock holds third-party packages only, as a single hub `@pub_deps`. Annotation versions move in lockstep with the generators the rules pin.
- **Targets:** `mcgen buildgen` emits all BUILD files through macros in `//tool/bazel:defs.bzl`. There is one library target per package, and codegen is wired per file through `dart_codegen`.
- **Code generation:**
  - freezed, json_serializable, go_router_builder and gen-l10n use stock support.
  - retrofit (a SharedPart shim), injectable (two-stage, vendored 3.1.3 without lean_builder) and bdd_widget_test (3.0.5 parser-based) get **new shims on our rules_dart fork**.
  - A shim that misses its Phase A timebox runs through the `build_runner` overlay (`tool/build_runner_overlay/`, outside the pub workspace) with committed, drift-checked outputs until it lands (plan README R28). The same contingency covers go_router_builder if its Flutter-closure spike fails.
- **App targets:** every app target is `manual`; there are no dart-defines or flavors in sim-debug (configuration is a Bazel-selected asset); iOS integration tests stay `manual` until patch U-F1.
- **Memory budget:** `--config=budget16` is defined once ([plan 04 §7.2](../plan/04-profiling-optimization-upstream.md)) and capped per worker mnemonic, singleplex and multiplex.

## Consequences
- **Positive:** hermetic, cacheable builds that are measurable at action level, and the precondition for the stress-test goal.
- **Negative:**
  - The pinned rules are alpha and change daily, so we upgrade deliberately behind our own bench (P4-18).
  - Three generator shims are on the critical path (Phase A).
