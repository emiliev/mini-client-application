# T-0073: `mcgen` search (SR) archetype: `discovery_search` and `characters_search` regenerate byte for byte

| Field | Value |
|---|---|
| Status | In Verification (Engineer handoff) |
| Owner | crew: Engineer (Sonnet, worktree). It follows the T-0069 pattern. |
| Verification | ADR-0015: `/code-review`, one fix round, then the TL merge gates |
| Branch | `fleet/T-0073-mcgen-search` |
| Created | 2026-11-28 |
| Depends on | T-0065, T-0069 (ADR-0017, `emit/common`), T-0046 (`discovery_search`, the SR exemplar), T-0071 (`characters_search`, a second SR module) |
| Related | plan 02 §2.3–§2.7, P2-05 to P2-07; F-0069; F-0046 and F-0071 (debounce, history, generation guard, paging per search) |

## Goal
Add the SR archetype to `mcgen`. The exemplar `discovery_search` (grouped results, no paging) and the hand-built `characters_search` (one domain, facets, paging) must **both** round-trip. That makes the template express both shapes.

## Scope
- **In:**
  - `tool/mcgen/lib/src/emit/feature_search/` and `tool/mcgen/bricks/feature_search_*`, plus specs for both modules (`exemplar: true`) and keep markers. Keep the markers comment-only and small.
  - The template must cover:
    - `DebouncedQuery` and `SearchHistory`, each with its own storage key;
    - the generation guard;
    - facets (sort and filter chips);
    - one paging controller per search, with the result list keyed by query and facets;
    - grouped results;
    - the minimum query length (2 in discovery, 1 in characters);
    - every state: idle, searching, results, empty, failure.
  - Reuse `emit/common`. Additions there must be additive and must not change the `list_detail` output.
- **Parallel work:** T-0072 (SC archetype) and T-0074 (wire/buildgen) are running. Own `emit/feature_search/` and `bricks/feature_search_*`. Additions to `emit/common` and `archetypes.dart` must be small and additive.
- **Out:** behaviour changes to either feature.

## Acceptance criteria
- **T-0073-AC1:**
  - `mcgen gen discovery_search --check` and `mcgen gen characters_search --check` both exit 0.
  - Changing a spec field makes `--check` exit 1 and name the file.
- **T-0073-AC2:** both features behave exactly as before. Their Bazel tests and the app tests are green. Their diffs contain only markers, `mcgen.yaml` and the manifest.
- **T-0073-AC3:** a throwaway SR module, with paging and one facet, generates, analyses clean and passes its BDD under Bazel, using a probe script.
- **T-0073-AC4:**
  - Gates: `test --lockfile_mode=error //...`, lint, the format gate, `T-0065-AC5_gates.sh`, and `characters_list --check` still up to date.
  - The lockfiles are unchanged.
  - Every cited test exists.
  - A short finding.

## Log
- 2026-11-28: Created and dispatched (TL), as part of the third wave.
- 2026-11-28 (Engineer, Sonnet): Done on `fleet/T-0073-mcgen-search`.
  - **Archetype** `search` (`lib/src/emit/feature_search/`, bricks `feature_search_di`, `feature_search_package` and `feature_search_build`). It has two modes, `paged` and `grouped`, that share the field, the debounce, the recent searches, the generation guard and the open guard.
  - **Exemplars:**
    - `discovery_search` (grouped: two groups, a client-side filter, a minimum length of 2) and `characters_search` (paged: sort and team facets, paging, a minimum length of 1) each have a spec (`exemplar: true`) and a manifest.
    - Each exemplar's diff against `main` is the spec, the manifest and the keep markers: one keep region, `search.open`, comment-only.
    - **One non-marker change:** three whitespace lines in `discovery_search.feature`. The Examples table had been aligned by hand, and the generator pads by string length (F-0073 §4.7).
  - **No change to `emit/common`.** `archetypes.dart` has one new line. `pseudo()` and the `feature_list_detail_failure` brick are reused as they are.
  - **Owned, not rendered:** the domain, the results widgets, the test env, the contract and flow-scope tests, BUILD, and the steps with no template. A new module (`options.skeleton`, paged only) gets working first writes of all of them.
  - **Probe** `zz_sr_probe`: `tool/mcgen/tool/T-0073-AC3_sr_probe.sh`. It runs gen, an idempotent `--check`, `build --config=lint`, and an uncached `test`: 7 of 7 BDD scenarios, contract, flow-scope and architecture tests.
  - **Pitfalls and hand share:** [F-0073](../findings/F-0073-mcgen-search.md).
  - **Tests:** nothing deleted or weakened. `tool/mcgen/test/search_test.dart` is new (18 tests).

## Outcome
**Status: In Verification.** Both exemplars regenerate byte for byte: 45 rendered files plus 4 owned step stubs for `characters_search`, and 35 plus 16 for `discovery_search`. A third, throwaway paged module generates, analyses clean and passes its BDD under Bazel.

| AC | Evidence |
|---|---|
| T-0073-AC1 | `tool/mcgen/test/search_test.dart`:<br>- `T-0073-AC1 mcgen gen discovery_search --check exits 0 against the exemplar`<br>- `T-0073-AC1 mcgen gen characters_search --check exits 0 against the exemplar`<br>- `T-0073-AC1 the round-trip golden of discovery_search: compareToExemplar finds the render identical to the real exemplar` (and `of characters_search`)<br>- `T-0073-AC1 a changed spec field makes --check exit 1 and name the file` (`characters_search_de.arb` line 4; `discovery_search_bloc.dart` line 26)<br>- `T-0073-AC1 a facet renamed in the spec changes the bloc, the event and the page, and --check names each`<br>- `T-0073-AC1 an edit inside the keep region keeps --check green; an edit outside one fails it`<br>- `T-0073-AC1 gen writes only the manifest into an exemplar, and the committed manifest is the one it writes` |
| T-0073-AC2 | - [T-0073-AC2_bazel_test_after.log](../evidence/T-0073/T-0073-AC2_bazel_test_after.log): `test --nocache_test_results` on both modules and `//app/...`, 45 of 45<br>- [T-0073-AC2_exemplar_diff.txt](../evidence/T-0073/T-0073-AC2_exemplar_diff.txt): the markers, the specs, the manifests, and the three whitespace lines<br>- `T-0073-AC2 the only keep region of each exemplar is the open handler, and the hand-written files are owned, not rendered` |
| T-0073-AC3 | - [T-0073-AC3_sr_probe.md](../evidence/T-0073/T-0073-AC3_sr_probe.md): gen, `--check`, `build --config=lint` and `test --nocache_test_results` all PASS, with 7 of 7 BDD scenarios<br>- `search_test.dart`:<br>&nbsp;&nbsp;- `T-0073-AC3 the probe spec lints clean and renders the same bytes in two roots`<br>&nbsp;&nbsp;- `T-0073-AC3 the probe is its own module, not an exemplar with names swapped`<br>&nbsp;&nbsp;- `T-0073-AC3 the template covers every behaviour the task names`<br>&nbsp;&nbsp;- `T-0073-AC3 a module with its own files gets none of the skeleton, and the skeleton files are owned`<br>&nbsp;&nbsp;- `T-0073-AC3 a step no template knows is written once, as a failing stub`<br>&nbsp;&nbsp;- `T-0073-AC3 search's lint names what a spec gets wrong`<br>&nbsp;&nbsp;- `T-0073-AC3 a prose slot no template uses fails gen, naming it`<br>&nbsp;&nbsp;- `T-0073-AC3 a missing de string is a lint error, not pseudo text` |
| T-0073-AC4 | - [gate_test_all.log](../evidence/T-0073/gate_test_all.log): `test --lockfile_mode=error //...` 246 of 246<br>- [gate_lint.log](../evidence/T-0073/gate_lint.log): `build --config=lint //...` PASS<br>- [gate_arch.log](../evidence/T-0073/gate_arch.log): `mc_arch_check` OK<br>- [T-0065-AC5_gates.md](../evidence/T-0073/T-0065-AC5_gates.md): the format gate, mcgen analyze, 164 mcgen tests, and lockfiles unchanged<br>- `T-0073-AC4 the list-detail exemplar still round-trips: the shared code is untouched` (`characters_list --check`: up to date)<br>- [F-0073](../findings/F-0073-mcgen-search.md) |

- **Hand share** (tool/loc):
  - `characters_search`: source 266 hand of 923, test 758 of 957, overall 1,024 of 1,880 (54 %);
  - `discovery_search`: source 379 of 910, test 882 of 1,019, overall 1,261 of 1,929 (65 %).
- **Keep regions:** `search.open` in each bloc. It is the only one: debounce, paging, the generation guard, facets and the history are all templates.
- **Follow-ups (for `pending-work.md`):**
  - a skeleton for the grouped shape, and for a nullable or second facet;
  - P2-08's buildgen should own `BUILD.bazel` and `flow_scope.dart`;
  - a 20-run flake check of the new `zz_sr_probe` targets is not meaningful, because the module is never committed.

## Review round (ADR-0015's single fix round)
- 2026-11-28 (Engineer): `/code-review` found 5 important issues. Each was a spec that lint accepted and gen then failed on or got wrong.
  1. **Roles.** Lint checks every `options.names` and `options.files` role of the mode (paged and grouped). `SrError` has a `toString`, so gen no longer prints "Instance of 'SrError'".
  2. **The open id type** comes from the argument of the navigator method `results.open` names (`m.openId`), in the bloc, its imports and the skeleton. The probe now has `ids: [SeriesId, ComicId]`, `openSeries` and `openComic`, and passes under Bazel.
  3. **`query.min_length` in paged mode** is honoured: the template adds `minQueryLength` and a guard that shows the recent searches. It is written only when the value is above 1, so `characters_search` is unchanged. The probe uses 2, with a BDD scenario for a one-letter query.
  4. **Barrel and architecture test:** lint requires `options.ids` to equal the navigator's argument types exactly (both directions).
  5. **`analytics.file` and `analytics.const`:** lint requires both or neither.
  - Removed the undeclared `// ignore: unused_element`, its typedef and the `yaml` import.
  - The bloc now imports only the open id's file.
  - **Accepted by the TL:** the whitespace-only change to the Examples table in `discovery_search.feature`.
- **Tests:** `T-0073-AC3 open takes the id type of the navigator method it names, not the first id`, `T-0073-AC3 lint names every missing role, id mismatch and half an analytics block, and gen never prints an SrError instance`, `T-0073-AC3 a grouped spec missing its roles is a lint error`. The probe's `min_length` is asserted in `T-0073-AC3 the probe is its own module, not an exemplar with names swapped`.
- **Follow-ups (nits not fixed):**
  - the skeleton should check the sort facet's `event` and `type`;
  - reject the other mode's option keys (`facets` in a grouped spec, `hits` in a paged one);
  - the bloc and DI docs say "at most 10" instead of using `history.cap`;
  - escape spec strings that are written into Dart literals (`history.key`, `analytics` names).
