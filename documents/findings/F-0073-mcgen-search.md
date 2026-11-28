# F-0073: The search (SR) archetype: what is a template, what stays hand-written, and the pitfalls

- **Date:** 2026-11-28
- **Author:** crew: Engineer (T-0073)
- **Type:** Design record / Lesson
- **Related:** T-0073, P2-05, ADR-0017, ADR-0016, ADR-0015, F-0069, F-0046, F-0071

## Summary
`mcgen gen discovery_search --check` and `mcgen gen characters_search --check` both exit 0. The `search` archetype renders the behaviour shared by every search feature and leaves the domain to the module.

- **Rendered (managed):**
  - the bloc, its events and its states;
  - the page and the recent-searches view;
  - the flow, the flow state, the navigator, the barrel, the ids and the screen-name constant;
  - the DI module, the DI initializer and the root-import list;
  - the ARBs, `.feature` files, `pubspec.yaml`, `l10n.yaml` and the architecture test;
  - the steps that need only the env: opening, typing and tapping, recent searches, paging, facet chips and the navigator contract.
- **Hand-written (owned):**
  - the domain: API, DTOs, mapper, the results or facets model, the repository;
  - the results widgets: the tile, the facet chips, the grouped view, the empty message;
  - the test env, the contract test, the flow-scope test, and `BUILD.bazel`;
  - every step with no template, as a failing owned stub.
- **Two shapes, one template:**
  - `mode: paged` (characters_search): one `PagingController` per search, server-side facets, the result list keyed by query and facets.
  - `mode: grouped` (discovery_search): one request for every group, a client-side filter, a minimum query length of 2.
- **The throwaway module** `zz_sr_probe` (comics, paged, one sort facet, page size 20) generates 46 files, analyses clean under `mc_analysis`, and passes 7 of 7 BDD scenarios plus its contract, flow-scope and architecture tests under Bazel ([T-0073-AC3_sr_probe.md](../evidence/T-0073/T-0073-AC3_sr_probe.md)).
- **Nothing was added to `emit/common`.** `archetypes.dart` gained one line. `pseudo()` is imported from `feature_list_detail/package.dart` (it was already public), and the `feature_list_detail_failure` brick is shared unchanged.

## 1. Hand share (tool/loc on the committed manifests)
| Module | source hand / scaffold | test hand / scaffold | overall hand |
|---|---|---|---|
| `characters_search` | 266 / 657 | 758 / 199 | 1,024 of 1,880 (54 %) |
| `discovery_search` | 379 / 531 | 882 / 137 | 1,261 of 1,929 (65 %) |

(`characters_list`, for comparison: 18 %.) The share is high on purpose, and it is where the two exemplars differ most:

- **Source:** the domain and the results widgets. `search_results.dart` (grouped hits, sections, the type filter) and `character_facets.dart` (sort enum, teams, query value) share nothing but the contract the templates call. A template would be a widget DSL, which P2-09 has not designed.
- **Tests:** the env (the fixture lookups are top-level declarations, which ADR-0016 keeps out of keep regions), the contract test, the flow-scope test and the steps that read a module's own widgets (`the characters section offers {..}`, `the results show the first {30} characters for {..}`).
- **Where a template can be reused:** discovery_search has 16 owned step stubs, characters_search 4. The managed steps are the ones that touch only the env's fixed names (`openSearch`, `tapResult`, `tapChip`, `shownHistory`, ...).

## 2. The contract between templates and a module's own files
A managed file calls these; a module (or the skeleton) provides them. `options.files` and `options.names` say where and how they are named:

| Mode | Names the templates use |
|---|---|
| paged | the entity (`Character`), its facets class with `with<Facet>` methods, the query class `(prefix, facets, offset, limit)`, the repository's `fetchPage(query)`, a tile `(<arg>: entity)`, a facets view `(facets:)`, and an empty-message expression (`options.results.empty_message`) |
| grouped | the results type with `isEmpty`, the hit type and its subclasses (one per navigator method), the filter enum with a default, a results view `(query:, results:, filter:)`, and the repository's `search(query)`, which answers `null` for "too short" |
| both | the env's names: `openSearch`, `searchNavigator`, `listArgument`, `shownHistory`, `searchHistoryKey`, `tapResult`, ... |

Imports follow from `options.files`, so a template never needs the module's symbols registered.

## 3. Keep regions: one
`search.open` in the bloc (`_Open`): the call that hands a result over. Its default is `_navigator.openCharacter(id);` (paged) or the `switch (hit)` over the hit classes (grouped). The markers are comment-only. A search often signs in first, tracks an event, or saves the result before it leaves, and this is the only place the two exemplars' bloc could differ in what an action does.

Nothing else in either bloc needed a keep region: the debounce, the generation guard, paging, the history version and the open guard are search semantics, so they are the template.

## 4. Template pitfalls (each cost a round)
1. **A plain YAML scalar ends at ` #`.** `example_title: Amber Chronicles #1` read as `Amber Chronicles`. Spec text with `#`, `: ` or a leading quote must be quoted.
2. **A part file's `part of` comes from the renderer.** A template that writes its own makes `dart format` fail ("only one part-of directive").
3. **Do not run bare `dart format` in a worktree.** Without `.dart_tool/package_config.json` at the root it formats in the wrong style (P-101) and rewrote one exemplar signature. Use `tool/checks/lib/format_gate.sh`; the round-trip caught the change at once.
4. **`<<<Name>>>` in a template is a generic.** `<<name>>` variables and Dart generics meet in `McBloc<<<Event>>, <<State>>>`: the regex matches leftmost-longest from the second `<`, which is right. Mustache bricks were not used for Dart text for the same reason (`{{` is not Dart-safe).
5. **The two exemplars' ARBs differ in layout.** discovery_search puts a description with placeholders on lines of its own; characters_search keeps everything on one line. `options.arb: block_placeholders` selects it. Placeholder JSON is written with a space after `:` and `,`, as the exemplars do.
6. **Gherkin comments in a Background are steps to the BDD parser, not to the step library.** `# Only the discovery domain...` renders as written, but must not become a step file (it did once, as `only_the_discovery_domain_the_strict_...dart`).
7. **An Examples table is padded by string length.** discovery_search's table was hand-aligned for a combining accent, so its first three rows had one space more than the generator writes. The only non-marker change in an exemplar is those three whitespace lines (T-0073-AC2).
8. **`dart format` outdents the end marker** that closes a `case`, as in F-0069. The template writes it at the statement indent and the formatter moves it, so both sides agree.
9. **A BUILD's test deps must not repeat a target's own.** `flow_scope_test` adds `mc_di` and `dio` itself, so a shared `_TEST_DEPS` that holds them fails to load ("Label ... is duplicated").
10. **Probe scenarios that read the recent searches** need `the app finishes writing to storage` before `I open the search again`: the save is real file I/O on fake time (F-0038 fact 1).
11. **The flow's `AnalyticsTracker` comes from `mc_monitoring`**, not `mc_analytics` (which the flow imports only for `AnalyticsFlowObserver`).

## 5. What P2-06 and P2-07 can reuse
- `emit/feature_search/tests.dart`'s step table (`_Step`): a template is its doc, signature and imports; the env name is the contract. Everything else is a stub, which keeps an exemplar round-trip honest.
- The owned-skeleton pattern (`skeleton.dart`, `skeleton_templates.dart`, `skeleton_build.dart`): a new module gets working owned files from `options.skeleton`, and an exemplar sets none.
- `ctx.deferred(..., owned: true)` for a BUILD file written once.
- The probe script (`tool/mcgen/tool/T-0073-AC3_sr_probe.sh`) and the probe test group in `search_test.dart`.

## 6. Not done, and why
- The skeleton writes a paged module with one enum facet named `sort`. A second facet, a nullable facet (a team) or a grouped skeleton is hand-written, as both exemplars are. The probe exercises the template with one facet, so the facet event and the `with<Facet>` call are checked, but a nullable facet is checked only by characters_search.
- `BUILD.bazel` is hand-written for an exemplar and a first write for a skeleton. P2-08's buildgen should own it.

## Evidence
- `T-0073-AC1 *`, `T-0073-AC2 *`, `T-0073-AC3 *` and `T-0073-AC4 *` in `tool/mcgen/test/search_test.dart`.
- The probe under Bazel: [T-0073-AC3_sr_probe.md](../evidence/T-0073/T-0073-AC3_sr_probe.md).
- The exemplars' diff against `main`: [T-0073-AC2_exemplar_diff.txt](../evidence/T-0073/T-0073-AC2_exemplar_diff.txt).
- Hand share: `fvm dart run tool/loc/bin/loc.dart . --json out.json`, modules `characters_search` and `discovery_search`.
