# F-0069: The list-detail archetype: hand share, the keep regions that had to exist, and template pitfalls

- **Date:** 2026-11-28
- **Author:** crew: Engineer (T-0069)
- **Type:** Design record / Lesson
- **Related:** T-0069, P2-04, ADR-0017 (proposed), ADR-0016, ADR-0015, F-0065, F-0066, F-0031, P-120

## Summary
`mcgen gen characters_list --check` exits 0. The `list_detail` archetype renders 52 files. 50 of them equal the exemplar byte for byte, and the other 2 are owned files that are checked only to exist.

- **Hand share** (tool/loc on the committed manifest):
  - source: 2 hand, 723 scaffold (0.3 %);
  - tests: 275 hand, 442 scaffold (38 %);
  - overall: 277 of 1,442 lines (19.2 %).
- **Keep regions:** only two had to exist, one line each. They hold what an action does: the preview's "See full profile" and a related comic's tap.
- **The rest of the hand-written code** is three owned test files:
  - the test env's fixture lookups;
  - the contract test;
  - the pre-ADR-0015 golden test.

  ADR-0016 allows keep regions only inside bodies, and this code is top-level declarations, so none of it fits in one.
- **The throwaway module** `zz_ld_probe` uses comics instead of characters, with other fields, another endpoint and page size, no filter and no section. It generates 44 files, analyses clean, and passes 7 BDD scenarios plus its contract, flow-scope and architecture tests under Bazel. None of its files mentions "character".
- **The exemplar's prose lives in its spec:** 19 `options.prose` slots and `doc:` keys. Most template prose is generic, and a template writes it from three nouns.

## 1. Hand share and where the hand lines are
| Part | Lines | Hand | Why |
|---|---|---|---|
| `lib/` (25 files) | 725 | 2 | the two keep regions |
| BDD steps (14), `.feature` (3), flow-scope and architecture tests | 442 | 0 | managed templates |
| `test/feature/util/characters_list_env.dart` | 104 | 104 | owned: fixture lookups (`CharacterUniverse(42, …).byName`, `_paged45`, `relatedComicsOf`) are top-level declarations |
| `test/contract/characters_api_contract_test.dart` | 116 | 116 | owned: the CONTRACT.md example and fixture facts |
| `test/golden/characters_list_golden_test.dart` | 55 | 55 | legacy (ADR-0015); BUILD keeps its target (`tests.legacy_goldens`) |

`tool/loc` counts a managed file as scaffold when its keep-stripped hash matches the manifest, so the manifest's hashes are those of the exemplar's own (header-less) form (ADR-0017 §1). Without a manifest, all 1,442 lines would be hand.

The spec is 509 lines: 196 BDD, 37 strings, 92 prose and 184 domain and options. It is YAML, not Dart, so tool/loc does not count it.

## 2. The keep regions that had to exist
- `preview.seeFullProfile` (`character_preview_bloc.dart`) and `section.RelatedComics.open` (`related_comics_bloc.dart`). Each default body is the navigator call.
- These are what an LD feature most often changes: an action may sign in first, toggle a favourite or track an event.
- No other exemplar body needed one. The list bloc's paging, the one-preview-at-a-time guard, the section bloc's double-Retry guard, `failureMessage`, the mappers and the repository are all list-detail semantics, so they are templates.
- **Pitfall:** `dart format` re-indents a comment that ends the last `case` of a switch to the `case` level. The end marker therefore sits two columns left of its body:

  ```dart
          case _SeeFullProfile():
            // mcgen:keep preview.seeFullProfile
            _navigator.openCharacter(state.id);
          // mcgen:end preview.seeFullProfile
  ```

  The formatter's placement is the one the gate accepts. KeepScan trims lines, so the marker is still found.

## 3. Template pitfalls (each cost a round)
1. **A brick named `BUILD.bazel` is a Bazel package.** `bazel test //...` failed to load `tool/mcgen/bricks/.../__brick__` (`syntax error at '}'`). The template is now named `{{{build_file}}}`, and `format_gate_test` guards that no brick holds a `BUILD`, `BUILD.bazel`, `WORKSPACE` or `MODULE.bazel`. The same trap would hit any future `.bzl` or `BUILD` template.
2. **`.dart` templates and the format gate (P-120 (a)).** The gate now replaces any directory that contains a `__brick__/` by its children, recursively. Everything else still reaches `dart format` as a directory, so behaviour elsewhere is unchanged: 1,360 files, 0 changed. `format_gate_test` runs the real gate in a scratch git repo, once with an unparseable `.dart` template and once with an unformatted ordinary file.
3. **Let `dart format` do the layout.** Emitters write one-line or naively split code without trailing commas, and the pinned formatter makes it the exemplar's layout. The first full render differed from the exemplar in only four files: an import, the spec file, a relative import, and one blank line. Trailing commas are written only where the exemplar forces a split that would otherwise fit (`['red', 'blue']`).
4. **A Dart raw string drops the newline right after its opening `'''`.** That cost the blank line between two `mcTestWidgets`.
5. **Flutter names are exported by several libraries** (`widgets.dart`, `material.dart`). A file imports exactly one of them. Templates therefore import Flutter and flutter_test by URI (`DartLibrary.imports`) and write their names plain. Only package and first-party names are `ref()`s, and those are what drive the pubspec and BUILD deps.
6. **The test env re-declares lib keys** (`charactersGridKey`), so test-file declarations register under `path:` URIs:
   - a test file prefers its module's own test declarations;
   - a `lib/` file never sees them;
   - a test-to-test import is written relatively, in its own `directives_ordering` section.
7. **Part files** (`characters_list_event.dart`, `_state.dart`) have no imports, so their references are resolved into their library's imports (`DartLibrary.partOf`).
8. **Extension members need an import but no name in the code:**
   - `context.read` needs `ReadContext`;
   - `context.di` needs `McFlowContext`;
   - `.toDomain()` needs the mapper.

   `use()` (and `«!Name»` in a template) records the import and renders nothing.
9. **The owned env's first write had an unused import** (`mc_mocked_backend`): the probe's record expression does not use `defaultMockClock`. Bazel's analyze aspect caught it. The env now imports exactly the spec's `tests.env.fixture_packages`.
10. **The exemplar's `en_XA` strings are hand-made.** The tildes are 33 % to 44 % of the length, with no single rule, so the spec carries them. A module without them gets `pseudo()` (accents, brackets, 40 % tildes rounded up).
11. **The usage example in a step's doc is the first use in the features,** except `the characters list shows {60} characters`, which the exemplar wrote from a later use. One prose slot overrides it.
12. **BUILD lists are rules over the use-graph.** Each reproduced the exemplar:
    - `_PURE_DEPS` is the pure files' packages plus `get_it` (injectable's output) and `json_annotation` (json_serializable's);
    - `_FLUTTER_DEPS` is the library's packages minus those, plus `flutter_localizations` and `intl` (gen-l10n's);
    - `_TEST_DEPS` is the BDD and flow-scope files' packages minus the flow-scope test's own fixed list (`mc_di`, `dio`, Flutter, `mc_test_utils`);
    - `_FREEZED` names are file stems, except `flow_state` and `list_bloc`;
    - `_CODEGEN` is ordered by stem, then target.

    `mc_ds_theme` is in the exemplar's deps but no file uses it, so the spec lists it (`deps: [mc_ds_theme]`).
13. **gen-l10n's file-name locale (P-120 (d), F-0066):** flutter_tools tries the whole stem, then the text after each `_`, with intl's `Locale.tryParse`, which also replaces deprecated codes. `auth_sign_in_en` therefore reads as `id_EN`. mcgen pins intl 0.20.3, the version flutter_tools 3.47.7 resolves, and copies flutter_tools' ISO 639-1 set. A test compares that set with the pinned SDK's source. Lint checks `<module>_<locale>` for the spec's locales plus `en` and `de`.

## 3a. Review round (after T-0071 changed the exemplar)
- **Merging the exemplar's own changes.** T-0071 added an app-bar action, a navigator method without an argument, a string, two features and four steps. The archetype gained a concept rather than exemplar text: **list actions**, which are guarded against double taps, have a keep region around the call, and get their own navigator-contract step and double-tap step. Filter steps are templates too. The round-trip went from 13 drifted files to 0 with no owned file added. Hand share after the merge: 278 of 1,543 lines (18.0 %).
- **Pseudo-translation must not touch ICU.** `pseudo()` used to turn `{count}` into `{çóúñţ}`, so gen-l10n would reject the ARB. It now keeps placeholders, plural/select keywords and selectors, and accents only their messages. The probe's `en_XA` plural passes gen-l10n under Bazel.
- **Only `en_XA` may be invented.** A missing `de` string used to ship pseudo text, and a missing `en` string crashed with a TypeError. Lint now checks every string for every locale, and the generator turns anything an archetype throws into a diagnostic.
- **Outlines** take their Examples from the rule's examples, with strings as Dart literals because steps read `{<column>}`.
- **Local junk:** the round-trip skips what git ignores, plus a fixed list for copies outside git.

## 4. What P2-05 to P2-07 can reuse
- **Exemplar mode** (ADR-0017 §1): `ownership: ejected`, `exemplar: true`, `owned:` for hand-owned files, and `gen --check` as the golden. Copy `list_detail_test.dart`'s AC1 group: the real-exemplar check, the field change, the ARB change, and inside and outside a keep region.
- **`lib/src/emit/common/`:**
  - `kit_symbols.dart`, with a test against the kits' barrels; add names there, never in an archetype;
  - `bdd.dart`: `.feature` rendering from the core `bdd`, bdd_widget_test's step naming, and the shared-step table, with a test against `mc_test_steps`' barrel;
  - `barrel_scan.dart`.
- **Core:**
  - `DartLibrary.imports`, `partOf` and `symbolUri`;
  - `ctx.dartBrick` with `«Name»` references;
  - `use()`;
  - `isBazelFile` headers and keep markers.
- **`feature_list_detail/common.dart` helpers:** `documented` (parameter and field lists with the exemplars' blank-line rule), `keepRegion`, `ty` and `participle`. Move them to `emit/common/` when a second archetype needs them.
- **`tpl()`** (`tests.dart`): raw templates with `<<var>>` and `«Name»`, no `$` escaping. This was the fastest way to transcribe an exemplar.
- **The pattern:**
  1. write the spec next to the exemplar;
  2. transcribe each exemplar file into an emitter or brick, replacing names by model getters;
  3. run `mcgen gen <exemplar> --check` until it is up to date;
  4. write a probe spec in `test/fixtures/` and run it through a copy of `tool/T-0069-AC3_ld_probe.sh`.
- **Not reusable as is:** `package.dart`'s BUILD brick is the LD staging layout (narrow DTO lane, F-0031 fact 4). P2-08's buildgen should own BUILD generation.

## Evidence
- `T-0069-AC1 *`, `T-0069-AC3 *` in `tool/mcgen/test/list_detail_test.dart`, and `T-0069-AC4 *` in `kit_symbols_test.dart`, `l10n_names_test.dart` and `format_gate_test.dart`: 136 mcgen tests pass ([T-0065-AC5_gates.md](../evidence/T-0069/T-0065-AC5_gates.md)).
- The probe under Bazel: [T-0069-AC3_ld_probe.md](../evidence/T-0069/T-0069-AC3_ld_probe.md).
- The exemplar is unchanged in behaviour:
  - 40 of 40 tests uncached, in [T-0069-AC2_bazel_test_after.log](../evidence/T-0069/T-0069-AC2_bazel_test_after.log);
  - a diff of markers plus the spec and manifest only, in [T-0069-AC2_exemplar_diff.txt](../evidence/T-0069/T-0069-AC2_exemplar_diff.txt).
- Hand share: `fvm dart run tool/loc/bin/loc.dart . --json out.json`, module `characters_list`.

## Implications / actions
- **ADR-0017** (proposed) records exemplar mode, the additive `mcgen/1` keys and the LD model.
- **Follow-ups for the TL:**
  - P-120 (c) (empty folders) and (e) (mcgen tests outside Bazel) are still open;
  - P2-08 should own BUILD generation and `flow_scope.dart`'s root-import list;
  - the owned env could shrink to its fixture lookups if a future ADR allowed keep regions around top-level declarations.
- **Prose slots are checked both ways.** gen refuses an `options.prose` slot that no template asks for, such as a typo or a slot a template change dropped (`T-0069-AC3 a prose slot no template uses fails gen, naming it`). A slot the spec leaves out falls back to its default, and for an exemplar the round-trip then shows the difference.
