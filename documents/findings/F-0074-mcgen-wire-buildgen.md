# F-0074: mcgen wire and buildgen: what the import graph explains, what it doesn't, and the glue that can be generated today

- **Date:** 2026-11-28
- **Author:** crew: Engineer (T-0074)
- **Type:** Design record / Spike result / Lesson
- **Related:** T-0074, P2-08, ADR-0018 (proposed), ADR-0016, ADR-0017, F-0065, F-0069, F-0049, F-0066, P-126, plan 02 §2.8 and §7.1

## Summary
- **buildgen.** `mcgen buildgen --check` agrees byte for byte with all 11 `feature/**/BUILD.bazel` files.
  - They were brought into the canonical form by `mcgen buildgen --adopt`.
  - The adoption is graph-neutral: before and after, `bazel query 'deps(//...)'` (10,769 lines), its 29,921 edges and every in-repo target's attributes (7,238 lines of `--output=build`) are identical.
- **wire.** `mcgen wire --check` agrees with:
  - all 11 `flow_scope.dart` files, now derived and no longer hand-maintained: 8 matched on the first run, and the other 3 once `context.di<T>()` reads counted;
  - the root workspace members (2 entries were out of order);
  - the app pubspec's `*_wiring` deps, unchanged;
  - three new wire-owned files: the app's wiring list, its `.bzl` and `GeneratedLocations`.
- **The probe (T-0074-AC3).** In a temp copy, one new list-detail spec plus `gen`, `wire` and `buildgen` gives an app that builds with `--config=sim`, passes `test //...` (252 of 252), and opens the new flow from `/catalogue`.
  - Only the spec was added by hand.
  - mcgen wrote 59 files: the module, a whole generated wiring group, the app's lists and the root pubspec.
- **What wire does not cover yet:** the 7 hand-written wiring groups, where the exemplars' routes live (§4).

## 1. The canonical BUILD form, and why a merge (ADR-0018)
A BUILD file is a function of the package's files, plus what a human owns:
- the comment block above each statement;
- a statement's own comments, kept while its code is unchanged;
- list items marked `# keep`;
- one hand region at the end (`# mcgen:keep build` … `# mcgen:end build`), whose statements override the generated ones of the same key.

**What buildgen reads, all by regular expression over directives and annotations** (`buildgen/dart_scan.dart`). The repo's code is formatted, so directives are regular:
- `part 'x.freezed.dart'` → a freezed target;
- a model with a `.g.dart` part → the json DTO and its narrow `_stage_dto` lane;
- `@RestApi` → the retrofit lane;
- `@injectable`, `@lazySingleton`, `@module` and the rest → the injectable shards;
- `l10n.yaml` → the gen-l10n attributes;
- `test/**/*_test.dart` with a `main` → test targets.

**The rules that reproduce the hand-written lists:**

| List | Rule | Agreed before `# keep` |
|---|---|---|
| `_PURE_DEPS` | imports of the pure globs' files, plus `get_it` (injectable output) and `json_annotation` (with a DTO) | 11 of 11 |
| `_FLUTTER_DEPS` | imports of every `lib/` file, minus `_PURE_DEPS`, plus `flutter_localizations` and `intl` (gen-l10n output) | 9 of 11 (`mc_ds_theme` is in characters_list and auth_signin, imported by nothing) |
| `_TEST_DEPS` | imports of `test/feature/step/**` and `test/feature/util/*`, minus what `mc_bdd_tests` adds itself | the derived set ⊆ the hand set in 11 of 11; 10 have extras |
| a test's own `deps` | `:pkg` plus the imports of its `main` (and of the util files when it imports them), minus `_TEST_DEPS` | most; extras such as `mc_storage` in 4 flow-scope tests |
| `_FREEZED` names | the name the BUILD file gave the source (`list_bloc`, `details_bloc`), else the file stem | 11 of 11 once carried over |

- The pure globs are a fixed candidate list (`di_module`, `flow_scope`, `domain`, `flags`, the flow state, `navigator`, `bloc`, `form`). Each is used when the package has a file that matches it. That reproduces all 11 `_PURE_SRCS`.
- **The extras are over-approximations, not missing rules.** For example, `mc_analytics` sits in 4 `_TEST_DEPS` lists, and no step or util file imports it. Removing an extra changes the graph (an edge), which AC1 forbids. So `--adopt` marks every unexplained item `# keep`: 75 items across the 11 files.
- Three files hold hand-region statements: 113 of their 3,865 lines (2.9 %):
  - trivia_quiz's engine lane (`_ENGINE_SRCS`, `_engine`, `engine_test`), its `architecture_test` with the engine list, and `outline_matches_contract_test`;
  - the `size = "medium"` legacy `golden_test` of library_reading_list_editor and store_home.

**Why not a pure template.** It would change 8 of the 11 graphs. **Why not a sidecar file.** It splits a target's truth across two files, and a reviewer can't see why an item is there.

## 2. What `--adopt` changed, exactly (commit `6802dab2`)
- `# keep` on 75 list items.
- `_FREEZED` and `_CODEGEN` sorted in 8 files; trivia_quiz's `_TEST_DEPS`, which had `mc_ds_buttons` before `mc_di`, sorted.
- auth_signin's `bloc_guards_test` moved before `unit_test`. Test order is `contract_test`, the tests that do not use the env (by main), `flow_scope_test`, the env-based ones, then `golden_test`.
- Three files' bespoke statements moved verbatim into the hand region.

None of these changes a target. `tool/mcgen/tool/T-0074-AC1_graph.sh` compares four views ([evidence](../evidence/T-0074/T-0074-AC1_graph_neutral.md)):
1. the labels of `deps(//...)`;
2. the same with each rule kind;
3. the edges;
4. every in-repo target's attributes, with list items sorted and location comments dropped.

A first comparison differed only in macro call-stack comments (`#   …/BUILD.bazel:306:13 in <toplevel>`). Those name a BUILD file line, and moving a statement changes them. The script now drops every comment line.

The app's own list of wirings moved to `app/mini_client/wirings.bzl` (`_WIRINGS = WIRINGS`), which wire writes. That move is graph-neutral by the same four views.

## 3. The flow scope can be derived from the source
`flow_scope.dart`'s list is R17's rule:
- **The inputs:** the parameter types of every `@injectable` / `@lazySingleton` constructor, every `@factoryMethod` and every `@module` member, **plus every `context.di<T>()` read** in `lib/`.
- **Minus** the types the package registers (class names, `as:` types, module return types) and what the flow provides (`FeatureFlowController`, the navigator interfaces, `provide:`'s `register*<T>`).
- `@factoryParam` parameters are passed at resolve time, so they are not dependencies.
- **Lesson:** without the `di<T>()` reads, 3 of the 11 files came out wrong. A page that reads `FeatureFlagsReader`, or the flow observer that reads `AnalyticsTracker`, needs a root import that no constructor names.
- **Where a type comes from:** the importing file's `package:` imports. A first-party barrel's exports come from `barrel_scan`; third-party names come from `thirdPartySymbols`. `AnalyticsTracker` is declared in `mc_monitoring`, not `mc_analytics`. A type no import explains is an error that names the file, never a guess.
- **Named parameters `{...}`** have to be split as well. The synthetic test (`T-0074-AC2 root imports: …`) caught this. No repo file needed it, so the round-trip alone would have missed it.
- The doc comment above the list is the package's own, carried over. All 11 hand-written files regenerate byte for byte, their "HAND-WRITTEN FOR NOW" prose included. A future edit can drop that line.

## 4. Which wire-owned files are covered, and which are not
| Plan 02 §2.8 file | Covered | How, or why not |
|---|---|---|
| each feature's `lib/src/di/flow_scope.dart` | **yes**, 11 of 11 | derived (§3) |
| root `pubspec.yaml` workspace members | **yes** | app/, feature/ and utility/ packages, sorted; spike/, third_party/ and tool/ members kept |
| the app's wiring list | **yes** | `app/mini_client/lib/src/wirings.dart` (new): `wiringInitializers`, `wiringRoutes`, `catalogueEntries`. `mini_client_app.dart` re-exports it and `app_router.dart` reads it |
| the app's pubspec deps | **yes** | only the `*_wiring` entries; the rest of the file is hand-written |
| the app's Bazel deps on the wirings | **yes** | `app/mini_client/wirings.bzl` (new) |
| `AppLocations` entries and drift tests | **for generated flows** | `GeneratedLocations` (app_core, new); each generated group's `test/routes_test.dart` checks each entry against its route. `AppLocations` stays hand-written (its entries belong to hand-written groups and carry their prose) |
| a wiring's routes, `RouteTargets`, impl and DI | **for generated groups** | the whole `app/wiring/<group>_wiring/` package, marked by `.mcgen/wire.json` |
| navigator implementation skeletons | **for generated groups**, written once | `openX(XId)` pushes `AppLocations.x(id.value)` when that method exists; otherwise an empty body for the engineer to map. Then the file is theirs: wire never rewrites it, and `--check` does not flag edits |
| the 7 hand-written groups' routes, targets and navigators | **no** | Their features are exemplars or hand-written, with no route specs. The routes carry prose, typed query parameters (`?q=`), nested paths (`/characters/:id`, `/characters/search`), `$extra` pickers and result routes (`AppFlows`), and the navigators hold mapping logic (sign-in requests, flow results). Generating them byte for byte needs a `route:` spec section for each exemplar first. Until then, **wire refuses a generated flow whose domain maps to a hand-written group**, naming the group (`tool/mcgen/mcgen.yaml` `wire.domains`) |
| `test/flow_scopes_test.dart` per wiring (plan 01 §4.5) | **no** | no hand-written group has one; each feature's `test/flow_scope_test.dart` resolves its flow's registrations |
| the sandbox's wiring list (`universe_sandbox`) | **no** | one hand-written group and its own router; the catalogue does not need it |
| root `BUILD.bazel` `dart_analysis_config` list | **no** | it has one options target, and nothing adds another |
| `BUILD.bazel` of utility packages | **no** | no archetype covers a utility package (`utility_hello` is the test-only reference archetype). The utility BUILD files vary: DS goldens, fixture assets, codegen lanes |
| `BUILD.bazel` of app/, app_core, the hand-written wirings and the sandbox | **no** | hand-written: an iOS app, a config `select`, per-route codegen lanes, and lane shapes that differ between groups (universe's `_ROUTES` is a string, chronicle's a dict, and chronicle's `_stage` includes its route file) |

## 5. Generated wiring groups and the catalogue (P2-08 AC1)
- **What wire generates for a managed or mixed spec.** The spec's domain (`feature/<domain>/`) names its group (`wire.domains` maps those that differ). A domain with no hand-written group gets `app/wiring/<group>_wiring/`:
  - a pubspec;
  - a barrel exporting `<Group>WiringDIInitializer`, the routes, the targets and `<group>Routes`;
  - one route library (`@TypedGoRoute` at `/<module-with-dashes>`, named after the module);
  - the route targets (feature barrels imported with prefixes, so two features' `ComicId`s never clash) and their implementation;
  - an injectable initializer for the navigators, the group initializer and `routes_test.dart`;
  - its BUILD file, written by buildgen in universe_wiring's shape.
- **The routes are absolute.** The app nests them under home with `nestUnderHome` (F-0049). The sign-in guard applies to their paths as to any other (F-0066): a flow under `/library/**` asks for sign-in, which `catalogue_test` expects.
- **`/catalogue`** is in app_core's `CataloguePage`. It lists `catalogueEntries`; a tile pushes the location, so Back returns to the list.
  - It is registered only when `!kReleaseMode`, and home has no link to it.
  - `analytics_screens_test` now expects `catalogue` plus one route name per entry. `app_test` checks the 7 hand-written initializers by name and order instead of `hasLength(7)`, so a generated group is allowed after them.
- **`//app/mini_client:catalogue_test`** (T-0074-AC3) reads `catalogueEntries`. A tree with a new generated flow therefore tests it with no edit:
  - the flow opens at its location, under its own route name;
  - the catalogue tile is gone from the screen;
  - Back returns to the catalogue.

  In the repo the list is empty, and a third test drives a synthetic entry, so the page's behaviour is tested either way.

## 6. Lessons and gotchas
- **`grep -q` under `pipefail`** fails the pipeline when its writer gets SIGPIPE. The first probe run reported "not PASSED" for six targets that had passed. Grep a captured variable instead.
- **macOS rsync has no `--ignore-missing-args`.** `git ls-files -co` lists a tracked file you have deleted in the working tree, and rsync then stops with a partial copy (mcgen then reported "package mc_api_client is used but unknown"). Filter the list with `os.path.lexists` first.
- **`directives_ordering` sorts by URI across a package's own and other packages.** `package:zz_ld_probe/…` sorts before `package:zz_probe_wiring/…`. The generated group's files sort each run of imports and exports at the end.
- **A navigator skeleton with no location to map** would leave a private `_routerRef` unused, and the analyze aspect fails on any diagnostic. The skeleton's field is public (`routerRef`).
- **Archetypes and the round-trip.** The round-trip now ignores `BUILD.bazel` and `lib/src/di/flow_scope.dart` (`defaultExemplarIgnores`).
  - An archetype that still renders one of them reports "rendered, but not in the exemplar". The search archetype (T-0073, merged mid-task) did. It now registers the root-import list as an external symbol, as list-detail does, and adds the list's packages (`dio`, `mc_di`, `mc_monitoring`, `mc_storage`) to its pubspec.
  - Its skeleton mode still writes an owned first `BUILD.bazel`. buildgen rewrites that file on its next run, so the two never conflict, but there are two writers (follow-up).

## Evidence
- AC1:
  - `T-0074-AC1 *` (11 tests) in `tool/mcgen/test/buildgen_test.dart`;
  - [T-0074-AC1_graph_neutral.md](../evidence/T-0074/T-0074-AC1_graph_neutral.md).
- AC2: `T-0074-AC2 *` (6 tests) in `tool/mcgen/test/wire_test.dart`.
- AC3:
  - `T-0074-AC3 *` (2 tests) in `wire_test.dart`;
  - `T-0074-AC3 *` (3 tests) in `app/mini_client/test/catalogue_test.dart`;
  - [T-0074-AC3_wire_probe.md](../evidence/T-0074/T-0074-AC3_wire_probe.md).
- AC4: [T-0065-AC5_gates.md](../evidence/T-0074/T-0065-AC5_gates.md) and the `T-0074-AC4_*.log` files.

## Implications / actions
- **ADR-0018** (proposed) records the canonical BUILD form and the wire-owned layout.
- **Follow-ups for the TL** (none filed in `pending-work.md`, which the TL owns):
  - (a) A `route:` spec section, plus specs for the exemplars' routes, so wire can own the 7 hand-written groups and generated flows can join them. That is the batches' common case (plan 02 §7.1: `comics_*` joins publishing).
  - (b) Shrink the 75 `# keep` items as packages are next touched: most are over-approximations.
  - (c) The search archetype's skeleton BUILD should go (ADR-0018 Decision 1); the SC archetype (T-0072) should emit neither file.
  - (d) buildgen for utility packages, once an archetype covers one.
  - (e) The CI mcgen gate now also runs `wire --check` and `buildgen --check` (`tool/ci/ci.sh` gate 6).
