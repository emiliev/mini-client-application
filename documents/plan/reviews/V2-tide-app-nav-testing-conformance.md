# V2: Conformance audit against Tide's application-layer, navigation and testing articles

| | |
|---|---|
| Task | T-0013, verification wave 3, Verifier **V2** (fresh; wrote none of the plan) |
| Date | 2026-11-23 |
| Sources (read in full) | application-layer **[app]**, navigation **[nav]**, testing **[test]** articles plus both diagrams; `[src Lnn]` = line in the scratchpad copy |
| Plan audited | `plan/README.md` (R1 to R28), `01` §2, §3, §4, `02` §2.2, §2.3, §2.7, `05` (all), ADR-0007, ADR-0010 |

## Verdict

**The plan follows these three articles in substance, but the plan text has gaps that must be fixed first.**

The core of all three articles carries over faithfully (matrix below), and most recorded deviations have sound reasons: per-flow child containers, go_router, the hardened `FeatureFlow`, the transport-level backend harness, data-before-open step ordering, R13's ban on defines, and the `BootBloc`.

The problems are in the text, not the design: sections not brought in line with the resolutions (01 vs R13, 02 vs R4/R6, 01 vs 05 on navigator delivery); three gaps (boot gating of go_router, app-layer coverage, R6 engine tests vs integrity rule R7); and R28's BDD fallback threatening AC traceability.

No blockers. Fix the majors before Phase C exemplars and P2-04 to P2-07, since mcgen multiplies the text ×100.

**Counts: 0 blocker, 7 major, 9 minor.**

## Findings

| id | sev | article ref | plan ref | issue | recommended fix | Resolution |
|---|---|---|---|---|---|---|
| V2-01 | major | [app L12–45, L163] run configs and the `--dart-define-from-file` bonus | R13; 01 §2 row 27, D-22, §3.4 (`config/{dev,e2e,perf}.json # --dart-define-from-file`), U04 `mc_config` ("AppConfig from `--dart-define-from-file`"), A09 "flavours"; 03 KD9 | R13 (★) bans defines and flavours in sim-debug. Plan 01's deviation table records the **opposite** (D-22 adopts the bonus's dart-define files), and U04 and A09 build on it. README says ★ rows "appear in 01 §2's deviation table", but this one contradicts it. | Rewrite D-22 and row 27 as R13: a Bazel-selected Dart config library (`select()` on a `--//config:env` flag) or a bundled `config/<env>.json` **asset** read at boot. Fix U04's description and remove "flavours" from A09. Note the bonus's benefit (one typed file per environment) is kept, and its motive (API keys) is moot per D-09. | fixed: R13 (Bazel-selected `app_config.json` asset), 01 D-22, row 27, §3.4, §5, U04, A09; P1-03 AC1, P3-07 AC4 |
| V2-02 | major | [nav L14] "a constructor that defines the feature's contract"; [test L343] the step builds the flow directly | 01 §3.3 (`CharactersListFlow({required this.navigator…})`, `provide: registerSingleton(navigator)`), §4.2; 05 §1.2 (`...s.externals // navigator mocks`), §3.5 (`initFlow(tester, () => const CharactersListFlow(), externals: [ExternalDouble<CharactersListNavigator>(…)])`) | There are two incompatible ways to deliver a navigator. 01 passes it through the flow constructor, which is the article's contract. 05 builds the flow with no navigator and injects the mock through the test container. 05's example doesn't compile against 01's flow (`required navigator`, and `const`). The navigator methods differ too (01 `openCharacter / openSearch / requestSignIn`, 05 `openComic`). | Make the constructor canonical. In steps: `initFlow(tester, () => CharactersListFlow(navigator: charactersNavigator()))`. Keep `ExternalDouble` for non-navigator externals only, and remove "navigators" from TD-02 and §1.2. Use one navigator interface for the `characters_list` exemplar in 01, 02's spec and 05. | fixed: constructor is canonical: 01 §3.3 navigator, 05 §1.1, §1.2, TD-02, §3.5 steps, 02 §2.2 spec (one interface) |
| V2-03 | major | [app L105–133] the BootPage is `home:` and builds the feature only when `initDi()` is done | 01 §3.4, §4.2 (route `build` calls `diContainer<CharactersListNavigator>()`), A01, A09 (`StatefulShellRoute`, deep links), P1-16 | The article's guarantee is that nothing feature-side builds before DI completes. With `MaterialApp.router` there is no `home`, and the plan never says how `BootBloc` gates the `GoRouter`. It is silent on when the router is created, on cold-start deep links that arrive while boot is pending, failed or retrying, and on the guard `redirect` running before `mc_session` exists. A route builder that resolves before DI is ready throws. | Specify `McApp`: `BootBloc` runs the root initializers, and the `GoRouter` is constructed (or its `redirect` releases a `/boot` hold) only on success, with the pending location preserved and replayed. Retry re-runs init and doesn't duplicate registrations. Add ACs to P1-16/P5-11 for a cold deep link during a slow or failed boot. | fixed: new R29; 01 §3.4 boot and router lifecycle; P1-16 AC5/AC6, P5-11 AC1 |
| V2-04 | major | [test L435] "Test only classes that are exported … if a class can't be tested via exported classes, delete it"; [test L430] | R6; ADR-0010; 05 TD-11, integrity rule R7 ("a test imports `package:<self>/src/` outside `test/contract/` → Fails"); 01 §3.3 (`test/unit/: pure engines only`) | R6 allows `test/unit/` for pure engines (quiz scoring, validators). Those engines sit in the feature's `src/` and aren't in the barrel (R4), so every such test fails R7. The exception isn't recorded against L435 either. Validators already have a utility home (U20 `mc_forms`). | Do it the Tide way: put pure, UI-independent engines in utility packages, where solitary tests are the norm (validators go in `mc_forms`; quiz scoring goes in a small `mc_quiz_engine` or similar). Otherwise record TD-16 and an allow-listed `test/unit/` exemption in R7. | fixed: R6 revised (no feature unit tests; engines to utilities or Scenario Outlines), 01 C7/D-30, P1-23 AC6, 05 integrity R7 |
| V2-05 | major | [test L436] "Aim for 100 % of coverage **in the package**. Set the 90 % threshold on CI" | R7; ADR-0010; 05 KD5, §1.3, §5.5 (`bazel coverage … //utility/... //feature/...`); 01 §8 (app layer 30.1k LOC) | R7 exempts "the app" and gates it by journeys. The coverage command leaves out all of `//app/...`, so **app_core and the 7 wirings**, about 14k hand-written lib LOC (BootBloc, guards, `AppLocations`, about 300 navigator implementations, result mappers), have no percentage gate. The mappers and guard hold real logic. | Gate `app_core` and `*_wiring` at 90 % (route tests and host journeys count); exempt only app targets. Amend ADR-0010. | fixed: R7, ADR-0010, 05 KD5, §1.3, §5.5, §5.6, 03 §6 |
| V2-06 | major | [test L430] "you shouldn't mock any internal classes"; [nav L331–334] the barrel exposes the flow entry point; [test L320–326] | 02 §2.3 (barrel "exporting only the flow(s)"; pages `BlocProvider(create: diContainer<…>)`; `test/unit/**` "repository and bloc tests (`mocktail`…)"), §2.7 ("bloc tests use `mocktail` repositories"), §2.2 (spec BDD "Given I am on…" / "backend responds with"; steps from `mc_test_utils`), `lib/l10n/` path; 02 test ratio 0.55 | The generator spec still encodes what R4, R6, R17, TD-05 and 05 C1 overturned. mcgen would stamp internal-mock tests and the superseded vocabulary into 100 features. | Before P2-04 to P2-07, edit 02 §2.2, §2.3 and §2.7 to match: barrel = R4; `context.di<T>()`; no bloc or repository unit tests (mapper round-trips go to `test/contract/`, rule examples go to Scenario Outlines); the 05 §3 vocabulary with data before open; steps from `mc_test_steps`; `lib/src/l10n/`; a feature test ratio of about 0.3. | fixed: 02 §2.2, §2.3, §2.7, §3.2, §2.8; P2-04..07 AC4 |
| V2-07 | major | [test L331–345] the generated test and stubs come from `build_runner` | R28; 05 KD4, TD-09, C4, §5.2, risks list; 01 §3.1 `.gitignore` (`test/feature/*_test.dart`), D-27 | If the BDD shim (P3-05) misses its timebox, R28 falls back to stock `bdd_widget_test` through `build_runner` with **committed** outputs. That conflicts with TD-09, D-27 and the `.gitignore`. AC traceability (KD4) also needs tags in test names, `testMethodName` and shared steps, which 05 marks "verify"; under the fallback ADR-0006's AC-ID rule could silently fail. | Verify the stock 3.0.5 options first in P3-05; make `trace_acs` map `.feature` tags → scenario titles → `test.xml` so it works in both modes (P5-07 AC); make TD-09, D-27 and the `.gitignore` conditional on R28. | fixed: R28; 05 KD4 (`mcTestWidgets` names tests), TD-09, §7.3 second join; 01 D-27; P3-05 AC5, P5-07 AC4 |
| V2-08 | minor | [nav L14] "ideally … the only class visible"; [nav L331–334] | R4 ★; 01 D-05, C4; 05 C6 | R4 is acceptable. The articles' own model (navigator contracts implemented at the application level) needs the interface to be visible. But the stated reason "tests need the navigators" is unsound: in-package tests can reach them (Tide's step imports `src/` [test L338]). Only the app needs them. Callback parameters on the flow constructor (flow-only barrel) weren't considered. | Restate the justification as "the app implements them". Add an `mc_arch_check` rule: barrels may export only `*Flow`, `*Navigator`, and flow arg and result types (no pages, blocs or DI initializers). That keeps R4 narrow. | fixed: R4 justification restated; `mc_arch_check` barrel rule (P1-01 AC5); 01 D-05, 05 C6 |
| V2-09 | minor | [test L261–268] reset inside `initializeDIContainer` | 01 D-17 ("`GetIt.reset()` moves from production init to test setup"); 05 §1.1 ("Kept in `mc_di`; `McTestSession` also resets") | The two sections contradict each other on where `mc_di` resets. | Adopt 01's version (a production reset is pointless with child containers) and update 05 §1.1. | fixed: 05 §1.1 adopts 01 D-17 (test-only reset) |
| V2-10 | minor | [test L320–326] Scenario titles | 01 §2 row 30, §3.3 ("title `T-XXXX-ACn …`"); 05 §3.1 ("no AC ID; the tags carry it"), §3.3 | The AC-ID placement conflicts between the two sections. | Use 05's tags and fix 01. | fixed: 01 mapping row 30, §3.3 BDD note (tags, 05 §3.3) |
| V2-11 | minor | [test L114–116, image 1] | 05 KD1 ("Features have no solitary unit tests"), C1 ("BDD + contract + l10n only") vs R6 and ADR-0010 (adds golden tests and an engine exception) | 05's key decisions are stale against R6. | Update KD1 and C1 to R6, after V2-04 is fixed. | fixed: 05 KD1, C1 (R6 as revised) |
| V2-12 | minor | [test L221–233] `TestContainer` registers what the flow needs | 05 §1.2 `mcTestInitializers` (monitoring, backend, api_client, storage, clock); 01 §3.3 `imports: [RootImport<Dio>, RootImport<Monitoring>, RootImport<Analytics>]`; 01 §3.4 root list (config, analytics, session, api_auth, flags, event bus, l10n core) | 05 says it "composes the **production** root initializers", but lists a subset. A flow that imports `Analytics` or `Session` fails in `initFlow`. | Build it as `rootInitializers(wirings: const [])` with edge overrides, and fail fast at `initFlow` if any `RootImport` can't be resolved. | fixed: 05 §1.2 (`rootInitializers(wirings: const [])` + overrides), 01 §5; fail-fast in `FeatureFlow` (01 §4.5, P1-04 AC6) |
| V2-13 | minor | [test L438] "Keep tests fast … more than a few seconds … split it" | 05 TD-12 (≤ 15 s per BDD target, split above 30 s) vs §4 estimates (LD about 21 s, FW about 26 s, DB about 19 s) | Every feature archetype misses the plan's own budget. | Budget per shard, or re-size features, or raise TD-12 explicitly and record it. P5-16 should confirm. | accepted deviation: TD-12 revised to ≤ 15 s per shard, `shard_count` from estimated suite time, split above 60 s; P5-16 confirms |
| V2-14 | minor | n/a (test budget basis) | 05 §2 diagram and §4 (150 modules, 115 features, 34 utilities); 01 (169 / 100 / 52) | The test budget is computed on a different catalogue, so the target counts, the "about 480 dependents" figure and the CPU estimates are off. | Recompute §4 and §5.4 against the 01 catalogue. | fixed: 05 §4 recomputed on 169/100/52 (7 archetypes), §2 diagram, §5.1, §5.4 (≈ 270 targets); 02 §5.1; 01 §8 points to 05 §4 |
| V2-15 | minor | [nav L12–14, L32] pages are the feature's business, changed without updating the app; image 1 | 01 §4.2 (nested paths `/characters/:id/powers`), §4.4; 05 §6.1 (`minicl://favorites`) vs 01 §4.4 (`miniclient://app/<path>`) | `powers` is a separate feature (F004), so the nesting is fine, but no rule stops a route from targeting a feature's internal screen. The deep-link schemes also disagree. | State the rule "a route builds a `*Flow`, never a page, and sub-screen deep links go only through flow arguments", and enforce it via R15's `RouteTargets` (barrel symbols only). Pick one scheme. | fixed: 01 §4.2 (routes build only flows, structural via R4), §4.4 (one scheme); 05 §6.1, P5-12 AC2; P1-01 AC6 |
| V2-16 | minor | [test L435] delete what exported entry points can't reach | 02 §3 realism variation; 05 §1.3 (below 100 % is "info") | Seeded realism code that no scenario reaches is exactly the dead code Tide says to delete. Under a 90 % gate it hides in the last 10 %. | Add a realism gate: every emitted public-in-`src` symbol is reached by at least one generated scenario, or mcgen doesn't emit it. Per batch, list uncovered lines for the Verifier. | fixed: 02 §3.8 realism gate 6 (reachability), P2-09 AC3 |

## Conformance matrix

F = follows · DR = deviates, recorded (soundness noted) · DS = deviates silently · M = missing.

### Application layer

| Item | Article | Plan | Status |
|---|---|---|---|
| App is glue that delegates | [app L10] | 01 key decisions, §3.4; R5 ★ | **DR, sound.** Splitting it into `app_core` + 7 wirings keeps every piece glue (routes, navigator adapters, mappers), and the stated rebuild and ownership reasons hold for 100 features. Weak spots: mappers and guards are untested by percentage (V2-05). |
| Utilities before features in the DI list | [app L90–102] | 01 §3.4 `rootInitializers` (utilities, then `...wirings`) | **F** |
| Features initialise themselves | [app L81]; [nav L127–132, L338–352] | 01 row 9; `flowInitializer` in each flow | **F.** This is the Tide production form, not the tutorial's simplification. |
| Boot page over `initDi()` | [app L105–133] | 01 D-21 `BootBloc` | **DR, sound** (it does the bonus), but router gating is **M** (V2-03) |
| Bonus: init failure | [app L161] | D-21; P1-16 AC1; P5-11 AC1 | **F** |
| Bonus: init timeout | [app L162] | P1-16 AC2 (> 10 s) | **F** |
| Theme on the app | [app L150–153] | `McApp` shell, `mc_ds_theme` (U24); `initFlow` theme (P5-01 AC4) | **F** |
| Run configs: dart-defines and launch.json, profile and release | [app L12–45] | R13 ★, 03 KD9 / KD12, `bazel run` | **DR, sound** (1.75 GiB worker); 01 contradicts it (V2-01) |
| Bonus: `--dart-define-from-file` | [app L163] | 01 D-22 adopts it; R13 forbids it | **DS / conflict** (V2-01) |

### Navigation

| Item | Article | Plan | Status |
|---|---|---|---|
| Two kinds, external imperative and internal declarative | [nav L16–22], image 1 | 01 §4.1 ("internal vs external") | **F** |
| External via go_router or auto_route | [nav L26, L369] | D-19 go_router + go_router_builder | **F** (this is the article's own bonus); typed routes are an addition |
| `feature_flow` utility over flow_builder | [nav L40–67] | `mc_feature_flow`, 01 §4.5; C11 spike | **F** |
| `FeatureFlow<T>`: state, `onGeneratePages`, optional initializer | [nav L87–106] | `FeatureFlow<S,R>` + `name`, `imports`, `provide`, l10n, `onComplete` | **DR, sound** (D-18 fixes real defects: with a null initializer the `FutureBuilder` never reaches `done` [nav L128, L151]; errors aren't handled) |
| `FeatureFlowController` registered for the bloc | [nav L122–123, L299] | 01 §3.3 bloc ctor `FeatureFlowController<S,void>` | **F** |
| get_it scope per flow (`pushNewScope` / `dropScope`) | [nav L115–117, L139] | Child `GetIt.asNewInstance()` + `RootImport`, InheritedWidget; R17 ★ | **DR, sound.** The global stack shadows across tabs and resolves only the top controller, undercutting [nav L115–116]. |
| Flow initializer runs in the flow's scope | [nav L125–132] | 05 §1.2 last paragraph | **F** |
| Flow state is a plain model, not one union case per screen | [nav L197–212] | 01 row 22; 02 spec `flow.state` | **F** |
| Bloc drives navigation through `controller.update` | [nav L265–309] | 01 §3.3 `_Preview`; §4.1 "only blocs call navigators" | **F** |
| Features export only the flow | [nav L14, L331–334] | R4 ★ (+ navigator, arg and result types) | **DR, acceptable**, but the justification is partly unsound (V2-08); 02 is stale (V2-06) |
| Navigator contract, implemented by the app | [nav L14] constructor = contract | 01 D-20 / §4.2; 05 §3.5 | **Conflict** between 01 and 05 (V2-02) |
| App wires external navigation | [nav L336–364] (only the BootPage swap) | 01 §4.2–4.4 (wiring navigator implementations over `GoRouter`, `AppLocations`, results, deep links) | **F / extension**; the screen-targeting rule is missing (V2-15) |
| Bonus: re-implement on Navigator 2.0 / auto_route | [nav L188–189] | C11 fallback | **F** (as a contingency) |

### Testing

| Item | Article | Plan | Status |
|---|---|---|---|
| Solitary unit tests for utilities: `test` + mocktail, `sut`, AAA, single purpose | [test L18–106] | 05 §1.1 row 1; 01 §3.2 | **F** |
| No-op mock factories (`createMockX`) | [test L51–58] | 05 §1.1; §3.5 `charactersNavigator()` | **F** |
| Sociable feature tests through the flow (Flow → Widget → Bloc → API) | [test L114–116], image 1 | KD1; ADR-0010 | **F** |
| Mock only external dependencies and the API | [test L430] | 05 §1.1 (monitoring, storage, clock, navigators, backend at transport) | **F.** Mocking the navigator counts as external (the app implements it), and that is sound. |
| `FeatureTestInterceptor` (path match, throws on unmocked) | [test L151–187] | TD-01 `McBackendHarness` over `mc_mocked_backend` (strict) | **DR, sound** (one fixture source; method and query matching) |
| `MockMonitoring` | [test L189–205] | exported from `mc_test_utils` (TD-03) | **DR, sound** |
| `TestContainer` | [test L207–240] | TD-02 `McTestContainer` (real Dio over the adapter) | **DR, sound**; the subset is inconsistent (V2-12) |
| `initFlow` | [test L242–259] | TD-04 (`McTestApp` with theme, l10n, iOS) | **DR, sound** |
| Reset DI between tests | [test L261–268] | 01 D-17 vs 05 §1.1 | **Conflict** (V2-09) |
| Test data from outside the implementation | [test L295] | TD-06, §3.4 test-facing facts; 02 C8 | **F**, provided spec `examples:` act as the API spec (see Notes) |
| Gherkin + bdd_widget_test; `/// Usage:`; one step per file; stubs hand-owned | [test L311–345] | 05 §3.1, §5.2; R12 (3.0.5) | **F**; the mechanism is at risk under R28 (V2-07) |
| Background "I am on…" then "backend responds" + `pumpAndSettle` | [test L317–376] | TD-05 (data before open; `mcSettle`) | **DR, sound.** The article calls it a convention that is "not always what we need" [test L376]. |
| Assertions on text | [test L378–398], bonus 3 [L429] | TD-07 (copy + `ValueKey`s) | **DR, sound** (it answers the bonus) |
| Image problem | [test L400–415] | TD-14 bundled assets | **DR, sound** |
| Bonus: refactor-proof tests; error copy test-first | [test L424, L428] | KD13 behaviour first; D-14 localised failures | **F** |
| Best practice: test only exported classes | [test L435] | R7 integrity rule; TD-11 contract exception | **DR (contract), sound**; R6 engines conflict (V2-04) |
| 100 % aim, 90 % CI gate per package | [test L436] | R7, ADR-0010, §1.3, §5.5 | **F** for utilities and features; **DS** for app-layer libraries (V2-05) |
| Keep tests fast; split slow packages | [test L438] | TD-12 | **DR**, but internally inconsistent (V2-13) |
| Plan 02's generated tests | [test L430] | 02 §2.3 / §2.7 | **DS** against R6 (V2-06) |

## Notes

1. **Enterprise content the plan should add:**
   - The article's dead-code rule ([test L435]) needs an enforcement path at generator scale (V2-16).
   - A boot and router lifecycle contract (V2-03), including state restoration and what happens to a flow's child container when go_router rebuilds a branch.
   - An explicit "a route builds only flows" architecture check (V2-15).
   -
2. **Test-data independence** ([test L295]) holds only if `mcgen.yaml` endpoint shapes and `examples:` act as the external API spec and DTOs never feed fixtures or contract schemas. Say so in 02 C8.
3. **flow_builder 0.1.x** uses the deprecated `Navigator.onPopPage`; C11's spike should cover iOS swipe-back reverting flow state, not just compilation.
4. **R5 judgement (requested by the README).** Splitting the app layer is true to the articles' intent. "Glue" is about responsibility, not package count. Wirings only translate intents into routes and adapt result types. The risk, mappers and guards growing logic, is contained by V2-05 and a review rule ("mappers are pure field maps").
