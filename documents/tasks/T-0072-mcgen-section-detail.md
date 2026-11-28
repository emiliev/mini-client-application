# T-0072: `mcgen` section-detail (SC) archetype: `comics_details` and `characters_details` regenerate byte for byte

| Field | Value |
|---|---|
| Status | In Verification (engineer handoff; ADR-0015 review next) |
| Owner | crew: Engineer (Sonnet, worktree). The pattern exists now (T-0069), so this task follows it rather than designing anew. |
| Verification | ADR-0015: `/code-review`, one fix round, TL merge gates |
| Branch | `fleet/T-0072-mcgen-section-detail` |
| Created | 2026-11-28 |
| Depends on | T-0065 (core), T-0069 (list-detail archetype, ADR-0017, `emit/common`), T-0041 (`comics_details`, the SC exemplar), T-0067 (`characters_details`, a second SC module) |
| Related | plan 02 §2.3–§2.7, P2-05 to P2-07 (templatise the remaining archetypes); F-0069 (the pattern and its pitfalls) |

## Goal
Add the SC archetype to `mcgen`. **Two real modules** must round-trip, the exemplar `comics_details` and the hand-built `characters_details`, which proves that the template generalises.

## Scope
- **In:**
  - `tool/mcgen/lib/src/emit/feature_section_detail/` and `tool/mcgen/bricks/feature_section_detail_*`.
  - Specs (`mcgen.yaml`) for both modules, with `exemplar: true`.
  - Keep-region markers: comment-only, few and small.
  - Reuse `emit/common` and the list-detail pieces wherever they fit. Put anything shared into `emit/common` additively. Don't change list-detail's output: `characters_list --check` must stay green.
  - The SC parts the template must express:
    - the favourite toggle, which signs in when needed and pins writes with `authPinned`;
    - the stale-read counter and the busy-announcement flag (T-0067);
    - section blocs;
    - outbound navigator methods.
- **Parallel work:** T-0073 (the SR archetype) and T-0074 (`mcgen wire`/`buildgen`) are running at the same time.
  - Own only `emit/feature_section_detail/` and `bricks/feature_section_detail_*`.
  - Additions to `emit/common` and `archetypes.dart` are allowed. Keep them additive and small. The TL resolves any registry-line conflict.
- **Out:** any behaviour change to either feature.

## Acceptance criteria
- **T-0072-AC1:** `mcgen gen comics_details --check` and `mcgen gen characters_details --check` both exit 0 on the merged modules. Changing one spec field makes `--check` exit 1 and name the file.
- **T-0072-AC2:** both features behave exactly as before. Their Bazel tests and the app tests are green, and their diffs are only keep markers, `mcgen.yaml` and the manifest.
- **T-0072-AC3:** a throwaway SC module (in a temp dir, not committed) generates, analyses clean, and passes its BDD tests under Bazel, using a probe script like T-0069's.
- **T-0072-AC4:**
  - Gates: `test --lockfile_mode=error //...`, lint, the format gate, and `T-0065-AC5_gates.sh`.
  - `characters_list --check` is still up to date.
  - The lockfiles are unchanged.
  - Every cited test exists.
  - A short finding records the hand share and the keep regions.

## Log
- 2026-11-28: Created and dispatched (TL), as part of the third wave.
- 2026-11-28 (Engineer, Sonnet): done on `fleet/T-0072-mcgen-section-detail`.
  - **The archetype** `section_detail`: `lib/src/emit/feature_section_detail/` (domain, flow, blocs, pages, tests, package, model) and the brick `feature_section_detail_package`. The model is the core spec plus `options`: `item`, `items`, `prefix`, `ids`, `entity`, `dto`, `item_path`, `opens`, and the optional `related` (a second request, as `characters_details` loads its comics), `cover` (an inner flow page, as `comics_details` opens its cover) and `analytics` (a saved favourite is tracked).
  - **Managed:** the barrel, DI, root imports, navigator, flow state, flow, API, repository, analytics vocabulary, the details bloc, the favourite bloc (sign-in, `authPinned` writes, the stale-read counter and the busy flag), the favourite toggle, the failure text, the ARBs, pubspec, BUILD, the `.feature` files, 19 step files, the favourites probe and the architecture test.
  - **Owned** (written once, then checked to exist): the model files, the page and its widgets, the cover page, the test env, the flow-scope test, the contract tests, the golden, and the steps about the page's own sections.
  - **Specs:** `comics_details/mcgen.yaml` (874 lines) and `characters_details/mcgen.yaml` (1,036), both `exemplar: true`, plus the manifests. Both round-trip.
  - **Keep regions:** `details.openCharacter`, `details.openCreator` (comics) and `details.openComic` (characters): the hand-over handlers, as marker lines in the exemplars' blocs.
  - **Shared code** (additive; `characters_list --check` stays up to date): `emit/common/options_reader.dart`; `bdd.dart` (steps starting with `#` or `|` are no step, `<name>` is a parameter, a table cell ending in a space is written as it is); one line in `archetypes.dart`.
  - **Probe:** `tool/mcgen/test/fixtures/zz_sc_probe/mcgen.yaml` and `tool/mcgen/tool/T-0072-AC3_sc_probe.sh`.
  - **Finding:** F-0072. **No test changed or removed.**
  - **Hand share** (tool/loc): `comics_details` 1,606 of 2,554 lines (62.9 %), `characters_details` 1,511 of 2,489 (60.7 %). Source 599/1,173 and 510/1,103; tests 1,007/1,381 and 1,001/1,386.

## Outcome
**Status: In Verification.** `mcgen gen comics_details --check` and `mcgen gen characters_details --check` exit 0; `characters_list --check` is up to date. 50 and 51 files are compared byte for byte, and 22 and 18 are owned (checked to exist). A throwaway SC module generates 45 files, analyses clean, and passes 8 BDD scenarios plus its flow-scope and architecture tests under Bazel.

| AC | Evidence |
|---|---|
| T-0072-AC1 | `tool/mcgen/test/section_detail_test.dart`:<br>- `T-0072-AC1 mcgen gen $name --check exits 0 against the merged exemplar` (both modules)<br>- `T-0072-AC1 $name: compareToExemplar finds the render identical to the real exemplar`<br>- `T-0072-AC1 $name: gen writes only the manifest, and the committed manifest is the one it writes`<br>- `T-0072-AC1 a changed API path makes --check exit 1 and name the API file (comics_details)`<br>- `T-0072-AC1 a changed ARB string makes --check exit 1 and name the file (characters_details)`<br>- `T-0072-AC1 a changed AC tag reaches the architecture test and names it`<br>- `T-0072-AC1 an edit inside a keep region keeps --check green; an edit outside one fails it` |
| T-0072-AC2 | - [T-0072-AC2_bazel_test_after.log](../evidence/T-0072/T-0072-AC2_bazel_test_after.log): `test --nocache_test_results //feature/comics/comics_details/... //feature/characters/characters_details/... //app/...`, 47/47<br>- [T-0072-AC2_exemplar_diff.txt](../evidence/T-0072/T-0072-AC2_exemplar_diff.txt): the diff against `origin/main` is the keep markers in two blocs, `mcgen.yaml` and `.mcgen/manifest.json`<br>- `T-0072-AC2 each hand-over handler of both exemplars is a keep region` |
| T-0072-AC3 | - [T-0072-AC3_sc_probe.md](../evidence/T-0072/T-0072-AC3_sc_probe.md) (`tool/mcgen/tool/T-0072-AC3_sc_probe.sh`): gen, idempotent `--check`, `build --config=lint` and `test --nocache_test_results` all PASS, 8 of 8 BDD scenarios<br>- `section_detail_test.dart`:<br>&nbsp;&nbsp;- `T-0072-AC3 the probe spec lints clean and renders the same bytes in two roots`<br>&nbsp;&nbsp;- `T-0072-AC3 the probe is its own module, not an exemplar with names swapped`<br>&nbsp;&nbsp;- `T-0072-AC3 a step no template knows is written once, as a failing stub`<br>&nbsp;&nbsp;- `T-0072-AC3 section_detail's lint names what a spec gets wrong`<br>&nbsp;&nbsp;- `T-0072-AC3 a prose slot no template uses fails gen, naming it`<br>&nbsp;&nbsp;- `T-0072-AC3 a section_detail spec for a missing entity is an emit diagnostic, not a crash` |
| T-0072-AC4 | - [gate_test_all.log](../evidence/T-0072/gate_test_all.log): `test --lockfile_mode=error //...` 246/246<br>- [gate_lint.log](../evidence/T-0072/gate_lint.log): lint PASS<br>- [gate_arch.log](../evidence/T-0072/gate_arch.log): `mc_arch_check` OK<br>- [gate_rules_fork.log](../evidence/T-0072/gate_rules_fork.log): `rules_fork.sh check` OK<br>- [T-0065-AC5_gates.md](../evidence/T-0072/T-0065-AC5_gates.md): the format gate (0 changed), mcgen analyze, 166 mcgen tests, lockfiles unchanged<br>- `characters_list --check`: up to date<br>- `section_detail_test.dart`: `T-0072-AC4 comment lines and data-table rows among a scenario's steps are written to the feature and are no step`, `T-0072-AC4 an outline placeholder is a step parameter like a {braced} one`, `T-0072-AC4 reflow fills a doc comment greedily and keeps lists`<br>- [F-0072](../findings/F-0072-mcgen-section-detail.md) |

- **Hand share:** about 61 %: see F-0072 section 1 for why (the pages and models are owned until P2-09).
- **Follow-ups (for `pending-work.md`):** see F-0072 "Implications".

## Review round (Engineer)
`/code-review` found 8 important issues, all specs that lint clean and then generate wrong or non-compiling code. Each is fixed with a test in `tool/mcgen/test/section_detail_review_test.dart` (and the AC3 probe script, which now builds three modules under Bazel: `zz_sc_probe`, `zz_sc_plain`, `zz_sc_story`).
1. The default `favourite_path` comes from `favourite_kind`. Test: `T-0072-AC3 the default favourites path comes from the kind, and the probe and the API use the same path`.
2. The favourites probe's URL comes from `favourite_path` (item differs from kind; a custom path). Same test; the probe's favourite BDD passes under Bazel.
3. No `opens`: the details bloc has no navigator, no guard, no timer and no `dart:async`. Test: `T-0072-AC3 a spec with no hand-over has no navigator in its details bloc, no guard and no timer`; `zz_sc_plain` passes its BDD.
4. Ids use their own `type` (API `@Path`/`@Query`, guard record, steps, env, favourites probe). Test: `T-0072-AC3 a two-word item and String ids: ...`; `zz_sc_story` analyses clean.
5. File stems use `snakeCase(item)` (`story_arc_details_bloc.dart`, the freezed targets). Same test.
6. An open with a `field` requires `<prefix>Open<Label>`. Test: `T-0072-AC3 an open with a field needs its Open<Label> string`.
7. Lint checks `entity`, `dto`, the related summary and page DTO (and `title`, the opens' fields) as diagnostics. Test: `T-0072-AC3 lint reports a missing entity, a DTO that is not one and a missing related entity, each as a diagnostic`.
8. The mapper wraps ids (null-checked when nullable), converts nested DTOs with `toDomain()`, and lists element by element. Test: `T-0072-AC3 the mapper converts nested DTOs, lists and nullable ids`; `zz_sc_story` analyses clean.
- **Shared code:** `renderFeature` now pads every Examples cell to its column; a column is as wide as its widest cell that does not end in a space, and a cell that does is hand-padded and kept when wider. A column with any hand-padded width is written exactly as given by the spec, so `characters_details` is byte-identical. Test: `T-0072-AC4 an Examples cell is padded to its column; a hand-padded one is kept only when it is wider`. `characters_list`, `discovery_search`, `characters_search` `--check` are up to date.
- **Also:** the skeleton page no longer declares an unused `l10n` when it has no hand-over; prose says "story arc" for `story_arc`.
- **Merged** `origin/main` (T-0073); `archetypes.dart` has `list_detail`, `search`, `section_detail`, `utility_hello`.
- **Gates at the review-round HEAD:** 194 mcgen tests; `test --lockfile_mode=error //...` 246/246; lint, `mc_arch_check`, `rules_fork.sh check`, the format gate and the lockfiles are clean (`documents/evidence/T-0072/`).
