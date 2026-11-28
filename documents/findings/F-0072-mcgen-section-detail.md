# F-0072: The section-detail archetype: hand share, the keep regions, and what a second module taught

- **Date:** 2026-11-28
- **Author:** crew: Engineer (T-0072)
- **Type:** Design record / Lesson
- **Related:** T-0072, P2-05, ADR-0017, ADR-0016, ADR-0015, F-0069, F-0065

## Summary
`mcgen gen comics_details --check` and `mcgen gen characters_details --check` both exit 0. The `section_detail` archetype renders 72 and 69 files. 50 and 51 of them equal the exemplar byte for byte, and the other 22 and 18 are owned files (step stubs included) that are checked only to exist (see section 1). `characters_list --check` is still up to date.

- **Hand share is high: about 61 %.** `tool/loc` on the committed manifests:
  - `comics_details`: source 599 of 1,173 hand, tests 1,007 of 1,381, overall 1,606 of 2,554 (62.9 %).
  - `characters_details`: source 510 of 1,103, tests 1,001 of 1,386, overall 1,511 of 2,489 (60.7 %).
  - `characters_list` (LD) was 18 %. The difference is a decision, not an accident: see section 1.
- **Keep regions:** three, one line each. They hold what a hand-over does (`_navigator.<method>(id)`): `details.openCharacter` and `details.openCreator` in `comics_details`, `details.openComic` in `characters_details`.
- **The throwaway module** `zz_sc_probe` (an issue, a hand-over to its series, no second request, no inner page, no analytics, other nouns) generates 45 files, analyses clean under `mc_analysis`, and passes 8 BDD scenarios plus its flow-scope and architecture tests under Bazel ([T-0072-AC3_sc_probe.md](../evidence/T-0072/T-0072-AC3_sc_probe.md)).
- **What an SC spec is:** a core spec (navigator, l10n strings, BDD) plus `options`: `item`, `items`, `prefix`, `ids`, `entity`, `dto`, `item_path`, `opens`, and optional `related`, `cover`, `analytics`. Two exemplars that differ in all three optionals are what shows the model generalises.

## 1. Hand share, and where the hand lines are
The archetype manages every file that is the same shape in both modules once nouns are swapped. It does not manage what each page does with its data.

| Managed (rendered, compared byte for byte) | Owned (written once, checked to exist) |
|---|---|
| barrel, DI initializer, root imports, navigator, flow state, flow | entity, DTOs, mapper (`<item>.dart`, `_dto`, `_mapper`) |
| API (retrofit), repository, analytics vocabulary | the details page, its section widgets, the cover page |
| details bloc, event and state; favourite bloc, event, state; favourite toggle; failure text | the test env, the flow-scope test, the contract tests, the golden |
| ARBs, `l10n.yaml`, `pubspec.yaml`, `BUILD.bazel`, the `.feature` files | steps about this page's own sections (stubs for a new module) |
| 19 shared and favourite step files, the favourites probe, the architecture test | |

- **Why the model files and the page are owned.** They differ in shape, not in nouns. `comics_details` has creators with a role enum, a cast and a price; `characters_details` has aliases, stats and a comics row. A spec language for them would be a widget DSL (P2-09), and neither exemplar could be reproduced from it. The archetype writes a working, smaller starting point from the spec's `entities` (the probe uses it) and the exemplar keeps its own.
- **Why the test env and the flow-scope test are owned.** As in LD (F-0069): fixture lookups are top-level declarations, and a keep region cannot hold those (ADR-0016).
- **Why 61 % and not 18 %.** `characters_list` was an LD module, whose pages and models are in the model of the archetype. SC pages are free-form. The honest number for the SC archetype is the share of what the page shows, and that stays hand-written until P2-09.
- **The spec is long** (874 and 1,036 lines), mostly because it carries the BDD (554 and 667 lines) and the strings (85 and 91). Prose slots: 20 and 29, for docs that are hand-wrapped differently per module.

## 2. The keep regions that had to exist
- Only the hand-over handlers: `details.<navigator method>`. Each default body is the navigator call. This is where an SC feature changes first: a tap may track an event, sign in, or open something else.
- No other body needed one. The load, the not-found rule, the double-tap guard, the stale-read counter and busy flag, the favourite's sign-in and `authPinned` write, and the section bloc logic are all the same in both modules, so they are templates.
- **The stale-read counter and busy flag** (T-0067) are in the favourite bloc's template, and the `characters_details` favourite bloc differs from `comics_details`' by exactly the analytics call: one `[analytics]` flag on three lines.
- The marker sits inside an `if` block, so the F-0069 pitfall (a `case`'s last comment is re-indented by `dart format`) does not apply.

## 3. What a second module taught (each cost a round)
1. **Raw templates generated once from the exemplar.** `favourite_templates.dart` and `step_templates.dart` were produced by a script that swapped the exemplar's nouns for `<<placeholders>>` and marked references with `«Name»`, then maintained by hand. This was the fastest way to reach byte equality: 18 drifted files on the first run, 0 after the prose slots were filled in.
2. **Doc comments are hand-wrapped, so greedy reflow is only a default.** The two exemplars wrap at 78 columns in some places and 72 in others. `reflow` (width 78) is the default for a sentence built from nouns, and a prose slot overrides it. Do not try to guess the rule.
3. **A `«Ref»` inside a string literal or a doc comment adds an import** (`'DataChanged("$topic")'` added `mc_event_bus` to a step that did not use it). Names inside literals are plain; doc text goes through `_plain`.
4. **A step's usage line is the first use in the features, except where it is not.** The exemplars' usage lines are hand-copied from a later scenario in 12 step files. Each is a prose slot (`step.<name>.usage`); `usage_slots` can be generated by diffing a render against the exemplar.
5. **Features carry more than steps.** A `.feature` may hold comment lines and data-table rows (`| 'key' | 'json' |`) among its steps, and a hand-aligned Examples table whose rows have different widths. In the spec, a step starting with `#` or `|` is written as is and is no step (`allSteps` skips it); a table cell ending in a space is written as is (`renderFeature`). An outline's `<scale>` placeholder without braces is a step parameter too.
6. **ARBs have a hand format**: a description alone on one line, and a description with placeholders on three lines (`"placeholders": {"number": {"type": "int"}}`). The SC writer reproduces it. LD's writes one line with compact JSON.
7. **BUILD order is by source path**, not by name: `_FREEZED` lists the entity, the DTO, the flow state, then the blocs. The retrofit action's deps have no `mc_api_client` (SC APIs return DTOs, not `ApiPage`). The hand files' own packages are not in the use-graph, so `options.build` lists them (`pure`, `tests`, `flow_scope`) and the core `deps` / `dev_deps` list the rest.
8. **Extension members need `use()`** as in F-0069: `context.read` (`ReadContext`), `context.mcPalette` (`McThemeContext`), `context.di` (`McFlowContext`), and the analytics extension method (`«!CharacterTracking»`).
9. **`favouriteKind` is not the item.** The probe's item is an `issue`, but the backend's favourites kind is `comic`. `options.favourite_kind` and `favourite_path` say so; the favourites probe and the API use them.
10. **The identity fixture set goes in the Background.** `I am signed in as` fails if `identity.default` is not served first.
11. **A new module's step stubs and fixture lookups.** A step about a hand-over (`the app was asked to open series {n}`) is a template only when the spec gives a lookup (`opens[].lookup`, with its type and id field) and the owned env defines it (`tests.env.extra` for the first write).

## 4. What went into `emit/common` and what P2-07 and P2-06 can reuse
- **`emit/common/options_reader.dart` (new, 100 lines):** `OptionsReader` and `OptionsError`, the typed reader for `options` that LD keeps as a private copy. Move LD to it when convenient.
- **`emit/common/bdd.dart` (three small additive changes):**
  - `allSteps` skips lines that start with `#` or `|`;
  - the step-parameter pattern also matches `<name>`;
  - `renderFeature` writes a table cell that ends in a space as it is.

  None changes LD's output: `characters_list --check` is up to date.
- **`archetypes.dart`:** one import and one line.
- **From LD, imported:** `emit/feature_list_detail/{common,tests,package}.dart` (`ty`, `documented`, `keepRegion`, `tpl`, `pseudo`) are re-exported through `feature_section_detail/common.dart`. They belong in `emit/common/`; a move is a pure rename.
- **Bricks:** `feature_section_detail_package` is a copy of LD's with the SC differences (retrofit deps, several contract targets, the flow-scope deps, the L10n class). `feature_list_detail_failure` is reused as it is.
- **The pattern** (same as F-0069): write the spec next to the exemplar, generate the templates from it, iterate on `gen --check` until it is up to date, then write a probe and run `tool/mcgen/tool/T-0072-AC3_sc_probe.sh`.

## Evidence
- `T-0072-AC1 *`, `T-0072-AC2 *`, `T-0072-AC3 *` and `T-0072-AC4 *` in `tool/mcgen/test/section_detail_test.dart`; the whole suite is 166 mcgen tests ([T-0065-AC5_gates.md](../evidence/T-0072/T-0065-AC5_gates.md)).
- The exemplars behave as before: 47 of 47 Bazel tests uncached, `comics_details`, `characters_details` and `//app/...` ([T-0072-AC2_bazel_test_after.log](../evidence/T-0072/T-0072-AC2_bazel_test_after.log)); the diff is keep markers, `mcgen.yaml` and the manifest ([T-0072-AC2_exemplar_diff.txt](../evidence/T-0072/T-0072-AC2_exemplar_diff.txt)).
- Gates: [gate_test_all.log](../evidence/T-0072/gate_test_all.log) (246/246), [gate_lint.log](../evidence/T-0072/gate_lint.log), [gate_arch.log](../evidence/T-0072/gate_arch.log), [gate_rules_fork.log](../evidence/T-0072/gate_rules_fork.log).
- The probe under Bazel: [T-0072-AC3_sc_probe.md](../evidence/T-0072/T-0072-AC3_sc_probe.md).
- Hand share: `fvm dart run tool/loc/bin/loc.dart . --json out.json`, modules `comics_details` and `characters_details`.

## Implications / actions
- **For the TL (pending work):**
  - P-120 (c) and (e) are still open;
  - P2-08 should own BUILD and `flow_scope.dart` for SC too (`options.build` exists only because the hand files are owned);
  - the SC page and model files are the P2-09 question; until then the SC hand share stays near 60 %;
  - move `ty`, `documented`, `keepRegion`, `tpl` and `pseudo` into `emit/common/` once T-0073 has merged (it will want them).
- **Prose slots are checked both ways**, as in LD: gen refuses a slot no template asks for.
