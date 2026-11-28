# F-0076: The dashboard (DB) archetype: hand share, the keep regions, and how one exemplar was generalised

- **Date:** 2026-11-28
- **Author:** crew: Engineer (T-0076)
- **Type:** Design record / Lesson
- **Related:** T-0076, P2-06, ADR-0017, ADR-0016, ADR-0015, ADR-0012, F-0056, F-0069, F-0072, F-0073

## Summary
`mcgen gen store_home --check` exits 0. The `dashboard` archetype renders 87 files for `store_home`: 63 managed files equal the exemplar byte for byte, and 24 step files with no template are owned stubs, checked only to exist. Every other `--check` is still up to date.

- **Rendered (managed):** the shared section base, one bloc, events and state per section, the session-dependent section, the paged detail page's bloc, the open-detail extension, the flow, its state, the navigator, the analytics vocabulary, the flags, the clock, the page, the barrel, the ids, DI, the ARBs, `l10n.yaml`, `pubspec.yaml`, the `.feature` files, the architecture test and 19 step files.
- **Owned:** the domain (API, DTOs, mapper, models, repository), the section widgets, the category page, the test env, the contract, flow-scope and golden tests, BUILD, and every step with no template.
- **Keep regions: five**, comment-only: `banners.open`, `banners.members`, `categories.open`, `deals.open`, `featured.open`. They hold what a tap does, which is where the sections differ most. `banners.members` holds the helper that routes a banner's target.
- **Spec:** the core spec (navigator, l10n, BDD) plus `options`: `prefix`, `sections` (each `list` or `session`), `flags`, `detail`, `ids`, `kinds`, `barrel`, `params`, `screens`, `tests` and `prose`. The exemplar spec has 114 prose slots, one per doc comment, so the exemplar's wording is data and a new module gets sensible defaults.

## 1. Hand share (tool/loc on the committed manifest)
| Module | source hand / scaffold | test hand / scaffold | overall hand |
|---|---|---|---|
| `store_home` | 1,325 / 1,127 | 1,339 / 351 | 2,664 of 4,142 (64 %) |

For comparison: LD 18 %, SC 61 %, SR 54 to 65 %. The widgets (865 lines) and the domain are most of the hand source. The test env, the flow-scope test and 24 steps are most of the hand tests. A widget DSL belongs to P2-09.

## 2. What the template parameterises
- **A section** is: its name, the item type its tap carries, what `fetch` answers, the state's `ready` parameters, an empty test, the repository method (or the whole `fetch` method as text, for deals), what it uses (`flow`, `navigator`, `clock`, `session`), an optional flag, and its tap handler (the keep region).
- **A session section** (`kind: session`) has its own template: the epoch rule, the reload on a session event, the sign-in tap, and the `isClosed` guard before an `add` after an await (F-0056 section 2). Its spec names the repository method that takes the epoch and what a tap opens.
- **The flag** is read once per visit in the page's state; a flagged section has no provider, so its bloc never exists.
- **The detail page** (`detail:`) adds the flow state's two fields, the open-detail extension, the paged bloc with its name lookup, the `Open<Detail>` class, the flow's two pages and the screen name.
- **Lint covers every role the emitters read** (F-0072 and F-0073's lesson): sections, kinds, ids, barrel, params, screens, tests, the flow and detail needs, the session keys, flags and the strings the page reads. `T-0076-AC3` has a rejection test for each role.

## 3. Pitfalls (each cost a round)
1. **A step template can call another step.** `only the section shows an error` imports `the section shows its error with retry`. A module whose features use only the first got a compile error. `emitTests` now emits the steps a template imports, used or not. The exemplar is unaffected.
2. **Owned fixtures need a suffix.** Probe files under `tool/mcgen/test/fixtures/` are stored as `*.fixture`, so mcgen's analyzer (2,348 warnings), the format gate and Bazel (a `BUILD.bazel` would make the fixtures directory a package) never see them. The probe script strips the suffix when it copies them.
3. **`dart format` decides the line break of `failure(ApiFailure error, {StackTrace? stackTrace})`.** A trailing comma written in the template is kept (`trailing_commas: preserve`), so the template writes none: short names fit on one line, long ones break.
4. **A keep marker closing a `case` is outdented by `dart format`**, as in F-0069; both sides agree because the render is formatted too.
5. **Hand-aligned Examples tables.** `store_home_sections.feature` pads one column by one space; a table cell that ends in a space is written as is (F-0072 section 3.5). The exemplar's only non-marker change is one trailing blank line removed from `store_home_cart.feature`.
6. **Scenario ids.** A non-exemplar spec needs `id: MC-<module>-NN` on every scenario; the probes add them.
7. **A `glob` that matches nothing fails a Bazel package.** The flags directory does not exist in a module with no flag, so probe A's hand-written BUILD drops that glob line. BUILD generation (T-0074) should do the same.

## 4. The probes (the generalisation proof)
`store_home` is the only DB module, so the probes carry the proof. Their spec and hand-written files live in `tool/mcgen/test/fixtures/zz_db_a` and `zz_db_b`; `tool/mcgen/tool/T-0076-AC3_db_probe.sh` copies each to `feature/zz_probe/`, runs `mcgen gen`, `gen --check`, `build --config=lint` and an uncached `test`, and deletes them again. See [T-0076-AC3_db_probe.md](../evidence/T-0076/T-0076-AC3_db_probe.md).

| | `zz_db_a` | `zz_db_b` |
|---|---|---|
| Sections | 3: deals, featured, cart | 5: banners, deals, categories, `spotlight` (flagged), cart (signed in) |
| Detail page, flag | none | paged category page; `spotlight` behind a flag |
| Navigator | 3 methods, one id | 4 methods, two ids |
| Result | 4 of 4 BDD, architecture, contract | 78 of 78 BDD, architecture, contract, flow-scope |

The hand-written files of both are `store_home`'s, copied under another module name by a script (`mkprobe.py`, not committed); A is cut to three sections and B renames its flagged section. What the probes prove is that the **managed** files (blocs, page, flow, analytics, flags, steps, ARBs, pubspec, architecture test) depend on the spec, not on the exemplar's nouns: B's section is `spotlight` with the bloc `Featured`, and A has no flow use, flags file or detail page. What they do not prove is that the hand-written domain and widgets generalise: they were not generated.

## 5. Not done, and why
- **`flow_scope.dart` is still rendered** (`_flowScope` in `flow.dart`), because T-0074 had not merged. It is dropped once `wire` owns it, in its own commit.
- **BUILD.bazel is owned.** For the probes it is `store_home`'s, edited by script (the golden and flow-scope targets, and the removed blocs, dropped).
- **Navigator-based steps** (`the app was asked to open comic ...`, the sign-in steps) are owned stubs. They read the env's navigator mock by name and could be templated like the others.
- **A skeleton** (a working first write of the domain, widgets and env, as SR has) was not written: the shapes of a section's data and widget are the P2-09 widget DSL.

## Evidence
- `T-0076-AC1 *`, `T-0076-AC2 *`, `T-0076-AC3 *` in `tool/mcgen/test/dashboard_test.dart`.
- The probes under Bazel: [T-0076-AC3_db_probe.md](../evidence/T-0076/T-0076-AC3_db_probe.md).
- Gates: [T-0065-AC5_gates.md](../evidence/T-0076/T-0065-AC5_gates.md), [gate_test_all.log](../evidence/T-0076/gate_test_all.log), [gate_lint.log](../evidence/T-0076/gate_lint.log), [gate_arch.log](../evidence/T-0076/gate_arch.log), [gate_rules.log](../evidence/T-0076/gate_rules.log).
- Hand share: `fvm dart run tool/loc/bin/loc.dart . --json out.json`, module `store_home`.
