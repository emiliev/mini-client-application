# T-0069: `mcgen` list-detail archetype: regenerate `characters_list` byte for byte (P2-04)

| Field | Value |
|---|---|
| Status | Handed off (TL review) |
| Owner | crew: Engineer (**Opus**: the first real archetype; it sets the pattern for P2-05 to P2-07) |
| Verification | ADR-0015: `/code-review`, one fix round, TL merge gates |
| Branch | `fleet/T-0069-mcgen-list-detail` |
| Created | 2026-11-28 |
| Depends on | T-0065 (`mcgen` core, ADR-0016), T-0032/T-0034 (the `characters_list` exemplar) |
| Related | plan 02 §2.2–§2.7, P2-04 (AC1: "Given the archetype's exemplar and its spec, when `mcgen gen` runs, then the output equals the exemplar except keep-region contents"), P1-24 (bricks); F-0065 §5 (extension points); P-120 (a), (b) and (d); ADR-0015 (no feature goldens; generated features follow it) |

## Goal
This is the first real template. Define the **list-detail (LD) archetype** in `mcgen`: bricks for the fixed-shape files and typed emitters for the variable ones. Then write `feature/characters/characters_list/mcgen.yaml`. Running `mcgen gen characters_list` must reproduce the merged exemplar **byte for byte**, except the contents of keep regions. Once that holds, any new LD feature is a spec plus generation.

## Scope
- **In:**
  - **Prerequisites from P-120:**
    - **(a)** The format gate must not break on brick templates. Skip `__brick__/` in `tool/checks/lib/format_gate.sh`, or name templates so they aren't `.dart`; pick one and document it.
    - **(b)** A shared table of the first-party kits' exported symbols (`McBloc`, `FeatureFlow`, `McFlowBackButton`, `Result`, `ApiFailure`, …), generated from or checked against the kits' barrels, so archetypes don't register them by hand.
    - **(d)** Spec lint rejects module names that gen-l10n misparses (for example a trailing `_in`, F-0066).
  - **`tool/mcgen/lib/src/emit/feature_list_detail/` and `tool/mcgen/bricks/feature_*`.** These cover every file of `characters_list`:
    - pubspec, BUILD, barrel;
    - DI (`di_initializer.dart`, `flow_scope.dart`);
    - domain models (freezed/json), API (retrofit), repository;
    - flow and flow state, navigator;
    - blocs and states, pages and widgets;
    - l10n ARBs (en, de, en_XA);
    - BDD `.feature` files and steps, contract tests, and any other tests in the package.
  - **Hand-written logic** that templates can't express goes inside **keep regions**. Add `// mcgen:keep <id>` … `// mcgen:end <id>` markers to the exemplar's hand-written bodies. These are comment-only edits to `characters_list`; its behaviour and tests must not change. Keep the keep regions few and small, and report the hand share (`tool/loc` on the manifest).
  - **The exemplar's existing goldens:** decide whether `mcgen` emits them, or the spec lists them as `owned:` files. ADR-0015 says no new feature goldens, so the archetype must not emit goldens for new features.
  - **The round-trip golden** is a `tool/mcgen` test that uses `compareToExemplar` against the real `feature/characters/characters_list`.
  - **Second LD module, the proof that it generalises:** a spec for a small **throwaway** LD module, such as `zz_ld_probe` in a temp dir, with different entities and endpoints. It must generate, pass `dart analyze` with `mc_analysis`, and pass its template BDD test under Bazel. Don't commit the module, only the test that generates and checks it.
- **Out:**
  - the other archetypes (P2-05 to P2-07);
  - `mcgen wire`/`buildgen` (P2-08): routes and wiring files stay hand-written for now;
  - spec synthesis.

## Acceptance criteria
- **T-0069-AC1 (P2-04 AC1):** `mcgen gen characters_list --check` exits 0 against the merged exemplar. A test proves that changing one spec field, such as an entity field or an ARB string, makes `--check` exit 1 and names the file.
- **T-0069-AC2:** the exemplar is unchanged in behaviour after the keep markers are added:
  - `bazel test //feature/characters/characters_list/...` and the app tests are green;
  - `git diff` of `characters_list` shows only marker lines and the new `mcgen.yaml` and `.mcgen/manifest.json`.
- **T-0069-AC3:** the throwaway LD module generates, analyses clean, and passes its BDD test under Bazel, inside an mcgen test or a script.
- **T-0069-AC4:** P-120 (a), (b) and (d) each have a test or check.
- **T-0069-AC5 (gates):**
  - `test --lockfile_mode=error //...`, lint, `mc_arch_check`, the format gate, `T-0065-AC5_gates.sh` (mcgen tests) and `tool/ci/ci.sh --only` for the mcgen gate.
  - The app's lockfiles are unchanged.
  - Every cited test exists.
  - Write a finding, `F-0069-mcgen-list-detail.md`, covering the hand share, keep regions that had to exist, and template pitfalls.

## Log
- 2026-11-28: Created and dispatched (TL), as the second hybrid wave.
- 2026-11-28 (Engineer, Opus): Done on `fleet/T-0069-mcgen-list-detail`.
  - **Core** (ADR-0017, Proposed):
    - exemplar mode (`exemplar: true`): `gen` writes only the manifest, and `gen --check` and `check` are the round-trip, as `round-trip` drift;
    - additive `mcgen/1` keys: typed query parameters, `l10n.strings`, Feature title and description, a multi-step Background, Scenario Outlines, and ids optional in exemplars only;
    - test files' symbols as `path:` URIs (relative imports; a test file prefers its own module's declarations);
    - `partOf`, explicit `imports`, `use()`, Dart bricks with `«Name»` references, and headers and keep markers for BUILD files.
  - **P-120:**
    - (a) the format gate skips `__brick__/`;
    - (b) `lib/src/emit/common/kit_symbols.dart`, checked against the kits' barrels;
    - (d) lint `l10n-name`, with mcgen pinning intl 0.20.3 as flutter_tools 3.47.7 does.
  - **`list_detail` archetype:** `lib/src/emit/feature_list_detail/` plus three bricks.
  - **`characters_list`:**
    - `mcgen.yaml` (ejected exemplar);
    - `.mcgen/manifest.json`;
    - two keep regions, as marker lines only (placed where `dart format` puts them).
  - **Test changes** (none weakened):
    - `spec_test.dart`: one lint message now says "mixed modules and exemplars";
    - `spec_test.dart`: the T-0065 test that expected `unknown archetype "list_detail"` now expects list_detail's own options error (the test said "P2-04 adds list_detail").
  - **Pitfalls** (F-0069 §3):
    - a brick file named `BUILD.bazel` broke `bazel test //...`, so it is named `{{{build_file}}}` now, with a guard test;
    - `dart format` outdents a keep end marker that closes a switch case.

## Outcome
**Status: Done.** `mcgen gen characters_list --check` exits 0. It compares 50 rendered files byte for byte and checks that the 2 owned ones exist; the only exemplar files not rendered are the spec, the manifest and the five legacy golden files. A throwaway LD module generates, analyses clean, and passes 7 BDD scenarios plus its contract, flow-scope and architecture tests under Bazel.

| AC | Evidence |
|---|---|
| T-0069-AC1 | `tool/mcgen/test/list_detail_test.dart`:<br>- `T-0069-AC1 mcgen gen characters_list --check exits 0 against the merged exemplar`<br>- `T-0069-AC1 the round-trip golden: compareToExemplar finds the render identical to the real exemplar`<br>- `T-0069-AC1 a changed entity field makes --check exit 1 and name the file` (character_dto.dart, line 17)<br>- `T-0069-AC1 a changed ARB string makes --check exit 1 and name the file` (characters_list_de.arb, line 3)<br>- `T-0069-AC1 an edit inside a keep region keeps --check green; an edit outside one fails it`<br>- `T-0069-AC1 gen writes only the manifest into an exemplar, and the committed manifest is the one it writes` |
| T-0069-AC2 | - [T-0069-AC2_bazel_test_after.log](../evidence/T-0069/T-0069-AC2_bazel_test_after.log): `test --nocache_test_results //feature/characters/characters_list/... //app/...`, 40/40, the same 40 as before (`(cached) 40/40` at `c1b08371`)<br>- [T-0069-AC2_exemplar_diff.txt](../evidence/T-0069/T-0069-AC2_exemplar_diff.txt): the diff against `origin/main` is the 4 marker lines, `mcgen.yaml` and `.mcgen/manifest.json` |
| T-0069-AC3 | - [T-0069-AC3_ld_probe.md](../evidence/T-0069/T-0069-AC3_ld_probe.md) (`tool/mcgen/tool/T-0069-AC3_ld_probe.sh`): gen, idempotent `--check`, `build --config=lint`, and `test --nocache_test_results` all PASS, with 7 of 7 BDD scenarios<br>- `list_detail_test.dart`:<br>&nbsp;&nbsp;- `T-0069-AC3 the probe spec lints clean and renders the same bytes in two roots`<br>&nbsp;&nbsp;- `T-0069-AC3 the probe is its own module, not the exemplar with names swapped`<br>&nbsp;&nbsp;- `T-0069-AC3 a step no template knows is written once, as a failing stub`<br>&nbsp;&nbsp;- `T-0069-AC3 list_detail's lint names what a spec gets wrong`<br>&nbsp;&nbsp;- `T-0069-AC3 a prose slot no template uses fails gen, naming it`<br>&nbsp;&nbsp;- `T-0069-AC3 the shared-step table is mc_test_steps' barrel` |
| T-0069-AC4 | - (a) `format_gate_test.dart`: `T-0069-AC4 a .dart template under __brick__ does not fail the gate`, `T-0069-AC4 an unformatted file beside a brick still fails it`, `T-0069-AC4 no brick template is a BUILD file, so Bazel never loads a brick as a package`<br>- (b) `kit_symbols_test.dart`: `T-0069-AC4 $uri exports every name the table lists` (one per kit), `T-0069-AC4 the scan finds what a barrel shows and hides`, `T-0069-AC4 registerKitSymbols resolves a kit name to its barrel`<br>- (d) `l10n_names_test.dart`: `T-0069-AC4 the locale gen-l10n reads, as flutter_tools reads it`, `T-0069-AC4 spec lint rejects auth_sign_in and passes auth_signin`, `T-0069-AC4 the ISO 639-1 set is the pinned SDK's, verbatim` |
| T-0069-AC5 | - [gate_test_all.log](../evidence/T-0069/gate_test_all.log): `test --lockfile_mode=error //...` 236/236<br>- [gate_lint.log](../evidence/T-0069/gate_lint.log): lint PASS<br>- [gate_arch.log](../evidence/T-0069/gate_arch.log): `mc_arch_check` OK<br>- [T-0065-AC5_gates.md](../evidence/T-0069/T-0065-AC5_gates.md): the format gate, mcgen analyze, 137 mcgen tests, and lockfiles unchanged<br>- [ci_gates_rows.txt](../evidence/T-0069/ci_gates_rows.txt): `ci.sh --only` 1, 5, 6, 7, 8 and 9 PASS<br>- [F-0069](../findings/F-0069-mcgen-list-detail.md) |

- **Hand share** (tool/loc): source 2/725, test 275/717, overall 277/1,442 (19.2 %). The test hand lines are the three owned files: env 104, contract 116, golden 55.
- **Keep regions:** `preview.seeFullProfile` and `section.RelatedComics.open`.
- **Follow-ups (for `pending-work.md`):**
  - P-120 (c) and (e) are still open;
  - P2-08 should own BUILD and `flow_scope.dart`;
  - keep regions around top-level declarations would let the env be managed (an ADR question).
