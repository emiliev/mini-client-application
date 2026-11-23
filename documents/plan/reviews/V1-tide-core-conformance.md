# V1: Conformance audit of the plan against Tide's core articles

| | |
|---|---|
| Task | T-0013, wave 3 (verification), Verifier **V1** (did not write the plan) |
| Date | 2026-11-23 |
| Primary sources (read in full) | *Project Miniclient — Introduction* `[INTRO]`, *Utility layer* `[UTIL]`, *Feature level* `[FEAT]`, plus the diagrams `introduction-1/2.png` and `feature-level-1.png`. I also grepped the navigation article to check the barrel claim in R4 |
| Plan audited | `plan/README.md` (R1 to R28), `plan/01-architecture-and-modules.md`, `plan/02-generation-and-scale.md` §2 and §3, ADR-0007, ADR-0010 |
| Local checks | (1) Dart 3.13.7 (`~/fvm/versions/3.47.8`) analysis of the plan's barrel shape under Tide's lint rules. (2) The freezed / freezed_annotation changelogs in `~/.pub-cache`. (3) A script over the §6.4 catalogue that checks the layering rules and looks for cycles |

## Verdict

**CONFORMS WITH ISSUES.**

The plan keeps every load-bearing rule in the three articles:
- the three layers and their dependency rules
- `lib/src` plus barrels
- the shared analysis package
- `Result` in a prelude
- the per-package injectable initializer
- a shared Dio with a retrofit API per feature
- repositories that return `Result`
- Bloc (not Cubit) with hand-written sealed events and freezed states
- monitoring in `onTransition`
- one DI call in the UI
- mason scaffolding

The catalogue is clean: none of its 169 modules has a feature→feature, utility→feature or lib→app edge, and the utility graph has no cycles.

There are no blockers. The issues are:
- one recorded deviation rests on a justification that is factually wrong (F1);
- the README's resolutions were never written back into plan 01 or 02, so the template sources contradict them (F2);
- a template trips one of Tide's own lint rules (F3);
- a set of smaller silent deviations and homework omissions.

## Findings

| id | severity | article ref | plan ref | issue | recommended fix |
|---|---|---|---|---|---|
| F1 | **major** | `[FEAT]` Presentation: state cases are **private** (`_LoadingMarvelCharactersState`…) and the page renders `state.when(...)` | 01 D-15, mapping row 18, §3.3 bloc/page; README R16; 02 KD12/C6 | The justification "`when`/`map` changed in freezed ≥ 3" is **stale**. freezed 3.0.0 removed them, but **freezed_annotation 3.1.0 (2025-07-02) "Added `when`/`map` back"**, and `FreezedWhenOptions.when` defaults to true (checked in `~/.pub-cache`). R10 pins exactly freezed_annotation 3.1.0. The real freezed-4 requirement is only the `sealed`/`abstract` class modifier. Switching to `switch` also forces the union cases to become **public**, which reverses Tide's deliberate scoping. Neither cost is recorded. | Either (a) keep Tide's shape: `sealed` freezed class, private cases, `state.when` (confirm that freezed 4.0.2 emits `when` in spike P3-01); or (b) keep `switch`, but re-justify it honestly (exhaustiveness, less generated code; X-series can measure the outline size) and record "union cases become public API of the bloc library" in D-15. |
| F2 | **major** | — (internal consistency of the recorded deviations) | README R4, R5, R6, R13, R15, R17 vs 01 §2.1/§3/§4.2/§5 and 02 §2.3/§2.7/§2.8 | The resolutions were not written back into the sections that templates and crew will read. **R13** (no dart-define) contradicts 01 U04 `mc_config` "from `--dart-define-from-file`", D-22, §3.4 `config/*.json # --dart-define-from-file` and §5 "Wiring". **R15** ("route files import a `RouteTargets` interface, not the features"; blocs import `package:bloc`) contradicts 01 §4.2, where the route `build` constructs `CharactersListFlow(...)` directly. **R4** is contradicted by 02 §2.3 ("barrel exporting only the flow(s)"). **R6** is contradicted by 02 §2.3/§2.7 (`test/unit/**` repository and bloc tests). **R17** is contradicted by 02 §2.3 (`BlocProvider(create: diContainer<…>)`). **R5** is contradicted by 02 §2.8 (wire files under `app/mini_client/lib/src/wiring/gen/`, not `app/wiring/<group>_wiring`). The README says ★ rows "appear in 01 §2's deviation table", but R6, R13 and R15 do not, and D-22 states the opposite of R13. | Update 01 §2.1 (add D-30 for R13 / codegen purity R15 / R6 and rewrite D-22), 01 §3.4/§4.2/§5/U04, and 02 §2.3/§2.7/§2.8. If that has to wait, at least add a "superseded by R-x" note at each point. This is needed before P1-17 and P2-04, because exemplars and bricks are built from these sections. |
| F3 | **major** | `[UTIL]` tide_analysis: `unnecessary_library_directive: true` | 01 §3.2 and §3.3 barrels start with `library;`; 02 §2.7 says "any diagnostic fails"; P1-01 AC4 | **Verified:** under Dart 3.13.7 with Tide's rules, a barrel that starts `library;` reports `unnecessary_library_directive`. Every barrel template would fail the `dart_analyze` gate. | Drop `library;` from the templates (Tide's barrels have no directive), or give it a doc comment. Add a template-lint golden to P1-24 / P2-04. |
| F4 | **major** | `[UTIL]` tide_di: one global `diContainer`; `[FEAT]` "`diContainer` … the only valid scenario for DI usage in the UI" | 01 D-17, §3.3 flow (`imports: const [RootImport<Dio>(), …]`), §4.5; README R17 | The deviation is recorded, and its rationale (scope shadowing in tabs) comes from the navigation article, which is V2's to judge. What is **not** recorded is its cost: each flow's `RootImport<T>` list is a new **hand-maintained contract**. Injectable's generated `getIt.init()` in the child calls `gh<Dio>()` and so on, so a missing import fails only at runtime, the first time something resolves. With about 100 features this is the most likely source of silent breakage. Tide's global container has no such failure mode. | `mcgen` should derive `imports:` from injectable's dependency graph, not take them from the spec. Add one BDD/contract check per feature: "every type registered in the flow scope resolves". Record the cost in D-17. |
| F5 | minor | `[FEAT]` bloc `onTransition`: `if (state is _ErrorMarvelCharactersState) await _monitoring.log(...)` | 01 D-16, U18 `McBloc`, P1-14 AC1 | Moving the logging into a base class keeps Tide's intent ("monitoring in one place, never in handlers"). But the plan doesn't say how a generic base class recognises the failure state, since the state types are per-bloc. | Specify the hook. Options: a `McFailureState` marker interface on failure cases via freezed `@Implements`, or a `Object? failureOf(S)` override. Add it to P1-14. |
| F6 | minor | `[FEAT]` "a page with just a BlocProvider … The page content itself is a mapper from bloc states" (`_MarvelCharactersPageContent`) | 01 §3.3 page template | **Silent deviation.** The template inlines the `BlocBuilder` in the provider widget instead of having a separate private content widget. This is small, but it is the shape every generated page will copy. | Template: `XPage` = `BlocProvider` only; `_XPageContent` = the state→UI mapper. |
| F7 | minor | `[UTIL]` `Result.fromAsync` catches `Exception` **and** `Error`, converting `Error` to a failure; `[FEAT]` repository uses `fromAsync` + `map` | 01 D-07, D-14, §3.3 repository (`Result.guard(…, ApiFailure.from)`) | The semantics of `Result.guard` are unspecified. In particular, does it still catch `Error`? JSON-shape bugs surface as `TypeError`, and Tide deliberately turns them into failures rather than crashes. | Define `guard` as: catch `Exception` and `Error`, keep the message (D-07), then `mapError`. `ApiFailure.from` must handle a non-Dio throwable (`ApiFailure.unexpected`). Add an AC to P1-02. |
| F8 | minor | `[UTIL]` "put as many files as we can under `src`" | 01 §3.3 `lib/src/l10n/…arb`; 02 §2.3 `lib/l10n/<m>_<locale>.arb` and per-feature `assets/**` | 01 and 02 disagree on the ARB location; 01's choice follows Tide. 02's per-feature `assets/**` also contradicts 01 D-24 (central `mc_fixtures_media`). | Use 01's paths in 02. |
| F9 | minor | `[INTRO]` layer rules; 01 key decision "only the app layer imports the umbrella" | 02 §2.2 spec example `deps: [… mc_design_system …]` for a feature | The canonical spec example declares a dependency the plan forbids for features. | Fix the example. `mcgen spec lint` should reject `mc_design_system` in feature specs. |
| F10 | minor | `[UTIL]` api_client bonus: compile-time base URL, **SSL pinning**, **`build.yaml` to optimise codegen**; tide_analysis bonus: enable more lints | 01 (no mention), 02 §2 | Homework is omitted without a recorded decision. (a) SSL pinning: not applicable to the mock adapter, but an enterprise `mc_api_client` should have a config-gated pinning hook for the real-backend mode, or record it as N/A. (b) `build.yaml` `generate_for`: Bazel's per-file `dart_codegen` replaces it, but pub/IDE mode (D7) and the R28 build_runner fallback still run build_runner over whole packages. (c) Lints: only `strict-inference` is added. | Record (a) and (c) as decisions in 01 §2. For (b), have bricks emit a `build.yaml` with `generate_for` per generator (cheap; helps R28 and IDE mode). |
| F11 | minor | `[INTRO]` "Miniclient" is the name of the toy project (a small version of Tide's main client) | README §3 "sandboxes, which are the 'miniclient' idea of running one slice standalone" | The attribution isn't supported by the introduction, utility or feature articles, and none of the six articles mentions sandboxes or standalone runs (grep). 01 mapping row 38 itself says "not described". | Re-word: sandboxes are our extension (D-29). R5 stands on its own reasons. |
| F12 | minor | `[UTIL]` one `tide_design_system` package | 01 D-12 | Part of the justification ("an API change fans out narrowly") doesn't hold for the core. Every feature's B set includes `mc_ds_theme`, `mc_ds_layout` and `mc_ds_feedback`, and so `mc_ds_tokens` transitively (edit #3: 134 dependents). The `Error`-shadows-`dart:core` reason is sound. | Restate the rationale: narrow fan-out for leaf DS packages, plus a deliberate stress shape. Keep it. |
| F13 | minor | `[UTIL]` barrels use `export 'package:<pkg>/src/…'` | 01 §3.2/§3.3 `export 'src/…' show …` | **Silent style deviation.** I checked that `always_use_package_imports` does **not** flag relative exports, so it passes the gate, but it differs from the article and from 02 §2.4 (the resolver writes `package:` URIs). | Use `package:` exports in barrels; keep `show`, which is a good addition. |
| F14 | minor | `[UTIL]` generated files sit in-tree and are excluded from analysis (`*.g.dart`, `*.freezed.dart`, `*.config.dart`) | README R28 vs 01 D-27, §3.1 `.gitignore` | R28's fallback **commits** retrofit, injectable and BDD outputs, which contradicts D-27 and the `.gitignore` list (it is, if anything, closer to Tide). The interaction isn't written down. | When R28 triggers: add per-generator `.gitignore` exceptions and a note in D-27, and keep the `mc_analysis` excludes (they already match Tide's). |

**Counts:** blocker 0, major 4, minor 10.

## Conformance matrix

| # | Rule / pattern (article) | Plan | Status |
|---|---|---|---|
| 1 | Three areas: utility, feature, app `[INTRO]` | 01 §1 | follows |
| 2 | utility → utility only `[INTRO]`, `[UTIL]` intro | 01 §1 table; catalogue has no utility → feature edges (script) | follows |
| 3 | feature → utility only, never feature → feature `[INTRO]`, `[FEAT]` navigator | 01 §1, catalogue (script: 0 violations); `mc_arch_check` P1-01 AC1 | follows |
| 4 | app may depend on anything; app is "glue" `[INTRO]` | 8 app-libs + 9 apps; wiring→wiring forbidden (R5, D-03) | deviates-recorded (sound: it is still all app layer and adds only rules, no new permissions) |
| 5 | Folder layout `app/`, `feature/`, `utility/` `[INTRO]` img 2 | `feature/<domain>/`, `tool/` (D-02) | deviates-recorded |
| 6 | `flutter create --platforms=android,ios` `[INTRO]` | iOS only (D-01, Q-009) | deviates-recorded |
| 7 | Shared analysis package in dev_dependencies; one-line `include` in every package `[UTIL]` | 01 §3.1, U01 | follows |
| 8 | Tide's lint set (22 rules, strict-casts, strict-raw-types, errors block, generated excludes) `[UTIL]` | D-06 + `strict-inference` | follows (but see F3: templates violate one rule) |
| 9 | `lib/src` encapsulation; export only through the barrel; "the less you export the better" `[UTIL]` | 01 §3; `show` combinators; `mc_arch_check` barrel-only | follows (F13 style) |
| 10 | Prelude `Result<S,F>`: sealed, private constructors, `fold`…`fromPredicate`, `success`/`failure` helpers `[UTIL]` | U02, D-07, P1-02 AC1 | follows + recorded extensions (sound; fixes a real defect) |
| 11 | Optional monad (bonus) `[UTIL]` | U02 | follows (homework done) |
| 12 | Unit test per `Result` function (bonus) `[UTIL]` | P1-02 AC1 | follows |
| 13 | `TideDIInitializer(fn)`, `DIContainer` (`call`, `isRegistered`), `initializeDIContainer(list)` `[UTIL]` | U03 `McDIInitializer` | follows (renamed) |
| 14 | Per-package `di_initializer.dart` + `@injectableInit` + `.config.dart` `[UTIL]`, `[FEAT]` | 01 §3.3 verbatim shape | follows |
| 15 | DI initializer is generated with mason in real projects `[FEAT]` | bricks `mc_di` (02 §2.4), D-25 | follows (extended) |
| 16 | Utilities that register things export their initializer `[UTIL]` | 01 §3.2 | follows |
| 17 | `api_client`: shared `@lazySingleton Dio` in a `@module`, auth interceptor, `@Named` keys `[UTIL]` | U16/U17; bearer instead of MD5 (D-09) | deviates-recorded (sound: no Marvel API, F-0003) |
| 18 | Generic envelope `MarvelResponse<T>` (`genericArgumentFactories`) exported from api_client `[UTIL]` | `ApiResponse<T>`, `ApiPage<T>` (D-10) | deviates-recorded (sound) |
| 19 | API keys / base URL via `String.fromEnvironment` `[UTIL]` | R13 forbids defines; 01 still uses `--dart-define-from-file` | deviates-recorded in README, **contradicted in 01** (F2) |
| 20 | Monitoring package: `@preResolve` init, Flutter error hooks, `Monitoring.log` `[UTIL]` | U05; console/in-memory sinks (D-11) | deviates-recorded (sound: no native SDK in v1; sinks mirror the Datadog-wrapper bonus) |
| 21 | Monitoring bonus: more methods, multi-backend wrapper, other Firebase-like services `[UTIL]` | `trackEvent`, `recordError`, `setKey`; `mc_analytics`, `mc_feature_flags` | follows (homework done) |
| 22 | Design system: theme + common `Loading` / `Error` widgets `[UTIL]` | 15 packages, `McLoading` / `McErrorView` (D-12) | deviates-recorded (sound; F12 wording) |
| 23 | DS bonus: customise the theme; more common widgets `[UTIL]` | U23 to U36 | follows |
| 24 | Feature bonus: no hardcoded padding; grid↔list by width `[FEAT]` | `mc_ds_tokens`, `mc_ds_layout` breakpoints, P1-11 AC3 | follows |
| 25 | Feature anatomy `di / domain{api,model,repository} / navigator / presentation/bloc` `[FEAT]` | 01 §3.3 (+ `flow/`, `page/`, `widget/`, `usecase/`, `l10n/`) | follows (use cases are named by `[FEAT]`; others are recorded, D-13) |
| 26 | Feature pubspec lists utilities as path deps, generators as dev deps `[FEAT]` | 01 §3.1, D-04, D-08 | follows + recorded (strict deps, workspace) |
| 27 | Models: freezed + `fromJson`, `@JsonKey(name:)` per field; response model beside domain model, split for big features `[FEAT]` | mapping row 15; DTO split in L-size features | follows |
| 28 | Retrofit API: `@injectable @RestApi`, `@factoryMethod factory X(Dio)` `[FEAT]` | 01 §3.3 | follows |
| 29 | Repository: unwraps the network model, handles errors with `Result` `[FEAT]` | `Result<T, ApiFailure>` via `guard` (D-14) | deviates-recorded (sound; F7 gap) |
| 30 | Bloc, not Cubit; bloc lives in `presentation/` `[FEAT]` | mapping row 18 | follows |
| 31 | Events: hand-written sealed class, private constructor, private subclasses, `part of` the bloc `[FEAT]` | 01 §3.3 (`_Load`, `_Open`…) | follows |
| 32 | State: freezed union, `part of` the bloc, **private cases** `[FEAT]` | public cases (R16) | deviates-recorded, **justification wrong** (F1) |
| 33 | Single `on<Event>` + `switch`; `load` added in the constructor; emit loading, then `fold` `[FEAT]` | 01 §3.3 | follows |
| 34 | Monitoring in `onTransition`, never in handlers `[FEAT]` | `McBloc` base (D-16) | deviates-recorded (sound; F5 gap) |
| 35 | Page = `BlocProvider` only; private content widget maps states → UI `[FEAT]` | inlined `BlocBuilder` | **deviates-silent** (F6) |
| 36 | UI renders the union with `state.when` `[FEAT]` | `switch` (R16) | deviates-recorded (F1) |
| 37 | DI in UI only via `diContainer<Bloc>()` in `BlocProvider.create` `[FEAT]` | `context.di<Bloc>()` (R17, D-17) | deviates-recorded (cost unrecorded, F4); 02 §2.3 still says `diContainer` (F2) |
| 38 | Feature entry point is always a widget; barrel exports the initializer + page `[FEAT]` (later the flow alone, navigation article) | flow(s) + navigator(s) + arg/result types (R4, D-05) | deviates-recorded (sound: navigators must be visible to wiring and tests); 02 §2.3 is stale (F2) |
| 39 | Navigator defined in the feature, implemented at the app level `[FEAT]` | `lib/src/navigator/`, implemented in `*_wiring` | follows |
| 40 | Code generation via build_runner; generated files in-tree, excluded from analysis `[UTIL]`, `[FEAT]` | Bazel outputs, not committed (D-27); R28 fallback commits them | deviates-recorded (F14 interaction) |
| 41 | `build.yaml` codegen optimisation (bonus) `[UTIL]` | — | **missing** (F10) |
| 42 | SSL pinning (bonus) `[UTIL]` | — | **missing** (F10) |
| 43 | Replace get_it (bonus) `[UTIL]` | — | missing, rightly (it would deviate from Tide; record it as declined) |
| 44 | More lints (bonus) `[UTIL]` | `strict-inference` only | follows partially (F10) |
| 45 | Testing BDD + widget tests (bonus) `[FEAT]` | P5, ADR-0010 | follows (V2 audits the details) |
| 46 | Navigation: flow_builder internally, auto_route externally (bonus) `[FEAT]` | `mc_feature_flow`, go_router (D-19) | deviates-recorded (sound: a stock rules_dart builder exists; auto_route would need another shim) |
| 47 | Network images `[FEAT]` page | bundled art (D-24) | deviates-recorded (sound: deterministic e2e) |

## Notes

**Q2: how sound the recorded deviations are.**

Sound and necessary:
- D-01, D-04, D-08, D-09 and D-10 (environmental constraints)
- D-07 (fixes a real `fromAsync` defect: the `Error` message is lost)
- D-12's rename (`Error` shadows `dart:core`)
- D-14 (localised, distinct failure states)
- D-24 and D-27

Sound for the project's goal, though not Tide-necessary:
- D-02 (domain folders)
- D-03 / R5 (app split)
- D-12's package split
- D-19 (go_router)
- R13 (no defines, because of worker memory)
- R15 (codegen purity)

My judgement on **R5**, as the README asks: it conforms in spirit. The intro rule constrains only utilities and features. Splitting the app layer adds restrictions (wiring ↛ wiring, features visible only to their own group's wiring) and grants no new edges. Features stay ignorant of each other, and the wiring stays glue.

Unnecessary, or cheap to bring closer to Tide:
- **R16 / D-15** (F1): Tide's `when` with private cases is available again under the pinned annotation.
- The page/content split (F6) and `package:` barrel exports (F13): zero cost.

**R6** is beyond this audit's articles; the feature-level article only points to BDD, so V2 owns it. **R17**: see F4.

**Q4: catalogue sanity.** The script parsed all 169 rows:
- No feature has a feature dependency. The `B` / `*+` sets in §6.2 contain only `mc_*` utilities, which I checked by hand.
- No utility depends on a feature or the app layer.
- The utility graph is acyclic.
- Fixtures and testonly packages reach features only as test deps.
- `mc_fixtures_discovery → mc_fixtures_{characters,comics,events}` is utility → utility, which is allowed. `mc_test_utils → mc_feature_flow` is also utility → utility.
- `app_core` depends on no features, as §1 requires.
- Layer counts (8/8/4/2/15/12/3 = 52) match the table.

**Outside this audit's articles (for the TL).** 01 and 02 disagree on mixins: 01 has "hot utilities contain no mixins", and U19 has "no mixins", while 02 §3.6 has 15 hot authored mixins, including `PaginatedBlocMixin`. They also disagree on locales: 01 has five, 02 §3.4 has `en` + `es` with 25 % adding `de`. Neither is a Tide issue, but both feed the same bricks.
