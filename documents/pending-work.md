# Pending Work

Known work that isn't yet a scoped task: ideas, deferred items, tech debt, follow-ups from handoffs. The Tech Lead triages these into tasks on the [BOARD](tasks/BOARD.md) when they become relevant. When an item is promoted or completed, note it and keep the row.

| ID | Item | Type | Source | When relevant | Promoted to / Done |
|---|---|---|---|---|---|
| P-001 | Testing strategy ADR: unit / widget / golden / integration, coverage targets | Decision | T-0001 | — | **Done** 2026-11-22 → [ADR-0006](adr/0006-verification-strategy.md) |
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
| P-012 | Consider Maestro (black-box YAML flows) alongside `integration_test` for e2e; needs a global install (Maestro CLI + JDK) | Tooling | ADR-0006 | If `integration_test` proves limiting | — |
| P-013 | Visual comparison against design mockups, if the PO provides designs | Quality → PO | ADR-0006 | When designs exist | — |
| P-015 | `tool/e2e_ios.sh`: per-target timeout (one target ran 370 s unbounded) | Tooling | T-0012 Verifier | Before Phase C e2e | — |
| P-016 | `tool/e2e_ios.sh`: trap SIGHUP; isolate two runs with the same role; narrow the evidence-reset PNG deletion | Tooling | T-0012 Verifier | With P-015 | — |
| P-017 | `tool/sim_cleanup.sh`: skip simulators whose owning `e2e_ios.sh` pid is still alive | Tooling | T-0012 Engineer | With P-015 | — |
| P-018 | Recompute plan 01's per-module test-LOC column (402k is an upper estimate; the real budget is about 250k per plan 05 §4) | Docs | T-0013 fix pass | When `tool/loc` exists (P2-02) | — |
| P-019 | Refresh plan 01 §7 graph metrics for the new `mc_feature_flow → mc_bloc_kit` edge | Docs | T-0013 fix pass | With P1-01 architecture guard | — |
| P-020 | Plan 04 §6.3 / KD-7 correction: `bazel analyze-profile` and `--verbose_explanations` are absent in Bazel 9.2.0 (T-0016). Re-check on 9.3.0 and update the flag inventory and the AC5 reference | Docs/Tooling | T-0016 | With T-0014 (Bazel 9.3.0) | — |
| P-021 | Compact execution-log ingestion: build Bazel's converter from the pinned 9.3.0 source (KD-7); JSON ingestion works today | Tooling | T-0016 | Before S1 perf runs | — |
| P-022 | `tool/perf` sampler: use a monotonic clock for intervals (a host sleep of 699 s made one AC7 run fail) | Tooling | T-0016 Verifier | Before nightly perf runs | — |
| P-023 | `--config=profile`: `%workspace%` isn't expanded in the trace and memory-profile paths (only the exec log is written, exit 0) | Tooling | T-0014 Verifier | Before P4 perf runs | — |
| P-024 | `spike_reference.sh` ignores a failed Bazel build (could compare stale outputs) | Tooling | T-0014 Verifier | Before P3-03 shims | — |
| P-025 | Reconcile the budget16 `--jobs` value between plan 03 and plan 04 | Docs | T-0014 | With P4-04 | — |
| P-026 | A debug simulator build also downloads the release iOS engine (fetch-cost upstream candidate) | Perf/Upstream | T-0014 | Phase F | — |
| P-027 | mcgen buildgen must emit `language_version` and the `sky_engine` codegen dep (F-0007, F-0011) | Tooling | T-0014 | With P2-08 | — |
| P-028 | A hung DI init blocks the BootBloc retry: add a timeout and cancellation to boot init | Feature | T-0017 Verifier | App-shell task | — |
| P-029 | Run `mc_arch_check` in the verify gate (`tool/verify.sh` / `bazel test`) | Tooling | T-0017 | With P5-09 | — |
| P-030 | The analyze aspect missed one `unnecessary_parenthesis` that `dart analyze` caught (possible rules_dart gap) | Upstream? | T-0017, F-0013 | Phase F | — |
| P-031 | Declare Inter in the Bazel app bundle (`flutter_application` fonts) so the app renders the DS font | Feature | T-0019 Verifier | App-shell task | — |
| P-032 | Restrict DS visibility from `//visibility:public` to the P3-06 layer package_group | Tooling | T-0019 | With P3-06 | — |
| P-033 | Move the `mc_ds_testing` golden harness into `mc_test_utils` | Tooling | T-0019 | With P5-01 | — |
| P-034 | `mc_mocked_backend`: a `once` rule is consumed even when the request then times out or is cancelled | Bug (low) | T-0018 Verifier | With P1-05 | — |
| P-035 | `mc_mocked_backend`: per-route latency overrides; contract JSON schemas | Feature | T-0018 | With P5-14 | — |
| P-036 | Lesson: parallel branches that predate a new lint or ruleset fail the post-merge gate; rebase before handoff when `main` gains shared rules | Process | T-0018 merge | Ongoing | — |
| P-037 | `mc_storage`: two stores on one directory race on one key; keys > ~123 bytes fail (file name too long) | Bug (low) | T-0020 Verifier | Before features persist data | — |
| P-038 | `mc_storage` `setKey` + in-memory store; `mc_media` package | Feature | T-0020 | With P1-03 follow-up | — |
| P-039 | **Upstream:** rules_flutter merges `dio` + `dio_web_adapter` (a pub cycle) into a Flutter target, which pulls `sky_engine` into pure-Dart closures and disables codegen summaries. Workaround: `cycle_breaks` (T-0023, F-0019) | Upstream | T-0023 Verifier | With P3-13 drafts | — |
| P-040 | `mc_api_client`: shorten Dio failure messages; clear the retry marker on the final error; wrap the `T-0023-AC5` check with an output base | Tooling | T-0023 Verifier | With P1-05 follow-up | — |
| P-014 | Re-enable Android: toolchain (Q-009 options a/b/c), CI APK build, emulator e2e | Quality | ADR-0006 §7, Q-009 | When the PO re-enables Android; before any Android release | — |
