# Tide "Project Miniclient": application layer, navigation and testing

| | |
|---|---|
| Task | T-0013 (research wave), crew Researcher, 2026-11-22 |
| Scope | The Application layer, Navigation and Testing articles. The Utility-layer and Feature-level articles are covered by a sister document and are used here only to resolve references. |
| Status | Research input for T-0004. This is not a decision. |

## Sources and citation keys

| Key | Article (Tide Engineering, Medium) | Published |
|---|---|---|
| `intro` | [Introduction](https://medium.com/tide-engineering-team/project-miniclient-introduction-0a94aefa5638) | 2024-07-17 |
| `utility` | [Utility layer](https://medium.com/tide-engineering-team/project-miniclient-utility-layer-fc9ff4a11d6f) | 2024-07-17 |
| `feature` | [Feature level](https://medium.com/tide-engineering-team/project-miniclient-feature-level-1030f3174e79) | 2024-07-17 |
| `application` | [Application layer](https://medium.com/tide-engineering-team/project-miniclient-application-layer-aecc0793e31f) | 2024-07-17 |
| `navigation` | [Navigation](https://medium.com/tide-engineering-team/project-miniclient-navigation-9d907345c6d1) | 2024-11-01 |
| `testing` | [Testing](https://medium.com/tide-engineering-team/project-miniclient-testing-14ac94a0ab2c) | 2024-12-09 |

Citations take the form `[key › section]`. The application article has no sub-headings besides "Bonus exercise", so its citations name the tutorial step (e.g. `[application › boot page]`). The untitled opening of the testing article is cited as `[testing › intro]`. **(inferred)** marks my own conclusions, including anything taken from general knowledge of a package rather than from the articles. The article code is tutorial code with misprints (§9.5). Excerpts are quoted as published.

---

## 1. Summary

1. **Three tiers.** The packages are `utility/`, `feature/` and `app/`. Utilities may depend only on utilities, features only on utilities, and the app on anything [intro › Project Structure]. The app is "just a glue between features, it should not be smart" [application › intro].
2. **App DI is an ordered list.** `initDi()` calls `initializeDIContainer([...utility, ...feature])` with a list of `TideDIInitializer`s (`MonitoringDIInitializer`, `ApiClientDIInitializer`, then `MarvelCharactersDIInitializer`). They run one after another, in order [application › DI; utility › DI — tide_di].
3. **Features end up initializing themselves.** After the navigation article, the feature initializer leaves the app's list and the feature's *flow* runs it in its own DI scope [navigation › Application]. The application article calls this Tide's real practice [application › DI].
4. **Boot.** `BootPage` is a `FutureBuilder` over `initDi()` that shows `Loading` until DI is done, then the feature entry widget. Failure and timeout handling are homework [application › boot page].
5. **Two kinds of navigation.** *External* navigation is imperative: push and pop or deep links, between features, via `go_router` or `auto_route`. *Internal* navigation is declarative and stays inside one feature, via `flow_builder` [navigation › Two types of navigation]. Tide's production app uses `auto_route` for external navigation [feature › Bonus exercise].
6. **The flow is a feature's only public class.** Its constructor "defines the feature's contract" [navigation › Two types of navigation]. The barrel exports only `MarvelCharactersFlow` [navigation › Marvel Characters].
7. **New `feature_flow` utility.** It provides `FeatureFlow<T>` and `FeatureFlowController<T>`, wrapping `flow_builder ^0.1.0`. A function `onGeneratePages(T) → List<Widget>` builds the stack from state [navigation › Feature flow].
8. **One `get_it` scope per flow instance.** Each flow pushes a scope, registers its controller there, runs the feature initializer into that scope, and drops the scope on dispose [navigation › Feature flow].
9. **The bloc drives navigation.** It calls `controller.update((s) => s.copyWith(selectedCharacter: …))`. Flow state is a plain `freezed` model, not a union of screens [navigation › Marvel Characters].
10. **Not built.** External navigation, cross-feature navigation contracts, deep links, flow results and back handling are all missing. The only hint is the feature-level `navigator` layer: an interface in the feature, implemented by the app [feature › structure].
11. **Two kinds of test.** *Solitary* unit tests (`test`, `mocktail`) cover utilities. *Sociable* BDD widget tests (`bdd_widget_test ^1.7.4`) cover features through the flow. They mock only external dependencies, and stub the API at a Dio interceptor [testing › Solitary Unit Tests; › Sociable Feature Tests].
12. **New `test_utils` utility.** It holds `FeatureTestInterceptor`, `MockMonitoring`, `TestContainer` and `initFlow()`. `initializeDIContainer` now resets `GetIt` first [testing › Creating a Test Utilities Package … Flow Initializer].
13. **Gherkin is the source.** The `.feature` file is processed by `dart run build_runner build --delete-conflicting-outputs`, which generates a `_test.dart` and step stubs that developers then edit [testing › Feature File; › Updating Step Files]. `tide_analysis` excludes `**/feature**/*_test.dart` [utility › Linter].
14. **Coverage policy.** Run `flutter test --coverage`. Aim for 100 %, and fail a PR on CI below 90 %. Test only the exported API, and split a package whose tests take more than a few seconds [testing › Testing Best Practices].
15. **Missing test layers.** There are no golden, integration, e2e or app-level tests, and no CI configuration.

---

## 2. Application layer

### 2.1 Responsibilities
- The app "combines different features… a sort of 'glue'" [intro › Project Structure]. Its job is "mostly to delegate the work to other components" [application › intro].
- In the tutorial it owns:
  - run configurations
  - its dependency list
  - the DI bootstrap order
  - the root widget (`MaterialApp`, theme, `BootPage`)
- It is created with `flutter create --platforms=android,ios miniclient` inside `app/` [intro › First Things First].

### 2.2 Run configurations and dart-defines
`.vscode/launch.json`, at the repo root, defines three `dart` configurations, all with `"cwd": "app/miniclient"`, so you can run the app "from any place in the project" [application › launch.json]:

| Name | Mode | Args |
|---|---|---|
| `miniclient` | debug | `--dart-define MARVEL_PRIVATE_API_KEY=<key>`, `--dart-define MARVEL_PUBLIC_API_KEY=<key>` |
| `miniclient (profile mode)` | `"flutterMode": "profile"` | none |
| `miniclient (release mode)` | `"flutterMode": "release"` | none |

- The defines are read by `api_client` (a utility), not the app, through `String.fromEnvironment(...)` in an injectable `@module` [utility › Networking — api_client].
- The profile and release configurations pass no keys **(inferred)**.

### 2.3 pubspec [application › pubspec]
- `name: miniclient`, `publish_to: 'none'`, `version: 1.0.0+1`, `sdk: ^3.2.0`, `flutter: ^3.16.3`.
- **Dependencies** (all path-based):
  - `api_client`, `tide_design_system`, `tide_monitoring` and `tide_di` (each `../../utility/…`)
  - `marvel_characters` (`../../feature/…`)
  - `flutter`
- **Dev dependency:** only `tide_analysis`. There is no `flutter_test` and no `build_runner`, so the app has no tests and no codegen **(inferred)**.

### 2.4 DI initialization
"Each feature and utility package has its own initializer. Most packages declare factories that will be used for instantiation lazily. At Tide, we tend to make features initialize themselves, however, let's simplify… and make the app call these initializers" [application › DI]. The file is `lib/src/di/di_initializer.dart`:

```dart
Future<void> initDi() => initializeDIContainer([
      ..._utilityDIInitializers(),
      ..._featureDIInitializers(),
    ]);

List<TideDIInitializer> _utilityDIInitializers() => const [
      MonitoringDIInitializer(),
      ApiClientDIInitializer(),
    ];

List<TideDIInitializer> _featureDIInitializers() => const [
      MarvelCharactersDIInitializer(),
    ];
```

- **Order matters.** `initializeDIContainer` awaits each `init(GetIt.instance)` in list order, so utilities come first: features consume what they register (`Dio`, `Monitoring`) [utility › DI — tide_di].
- **Why boot is a `Future`.** `MonitoringDIInitializer` is asynchronous, because it `@preResolve`s `Firebase.initializeApp` [utility › Monitoring].
- **Later changes.** The list later shrinks to utilities only (§3.5), and the function gains a reset step (§4.4).

### 2.5 Boot page, `main.dart` and theme
- **Boot page.** `lib/src/presentation/boot_page.dart` is a `StatefulWidget` whose state holds `final initialization = initDi();` [application › boot page].
  - It builds a `FutureBuilder`. Until the future is `done` it shows `const Loading()` from `tide_design_system`; after that, `const MarvelCharactersPage()`, which becomes `const MarvelCharactersFlow()` later [navigation › Application].
  - `done` is also reached when DI fails, so a failure still renders the feature **(inferred)**.
- **`main.dart`.** `runApp(const MyApp())`, where `MyApp` builds `MaterialApp(title: 'Miniclient', theme: miniclientThemeData, home: const BootPage())` [application › main.dart].
- **Theme.** `miniclientThemeData` comes from `tide_design_system`: `ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true)` [utility › Design system].
- **No router.** There is no `navigatorKey` and no `onGenerateRoute`.

---

## 3. Navigation

### 3.1 Concept
- **Navigation is a UI detail.** "Navigation is an implementation detail for the UI." A feature may show more data inline, add a details page, use a bottom sheet, or adapt per device "without the need to update the application package" [navigation › Two types of navigation].
- **Flow.** "An entry point to a feature. Ideally, it should be the only class visible outside the feature, with a constructor that defines the feature's contract" [ibid.].
- **External navigation** "orchestrates the navigation between features… a good old imperative approach, like pushing and popping screens or using deep links to initiate specific flows" [ibid.]. The article points to `go_router` and `auto_route` but implements neither [navigation › External navigation].
- **Internal navigation** is "a declarative paradigm [that] drives the feature's internal navigation stack". It lets "UX changes within a feature [happen] without affecting the overall application" [navigation › Internal navigation].
- **Packages.** Navigation uses `flow_builder ^0.1.0` (by Felix Angelov), `get_it ^7.6.4`, `tide_di` and `freezed`; see §5.

### 3.2 The `feature_flow` utility package [navigation › Feature flow]
- **pubspec.** It sits under `utility/` with `version: 0.0.1` and `publish_to: none`. Dependencies are `flutter`, `flow_builder ^0.1.0`, `get_it ^7.6.4` and `tide_di` (path); the dev dependency is `tide_analysis`.
- **Files.** The code lives in `lib/src/feature_flow.dart`, exported through the barrel `lib/feature_flow.dart`.

| Symbol | Kind | Members |
|---|---|---|
| `OnGeneratePages<T>` | typedef | `List<Widget> Function(T state)` |
| `FeatureFlow<T>` | `StatefulWidget` | `required OnGeneratePages<T> onGeneratePages`, `required T state` (the initial state), `TideDIInitializer? flowInitializer` |
| `FeatureFlowController<T>` | class | `FeatureFlowController(T state)`, `T get state`, `update(T Function(T))`, `dispose()`. It wraps a private `flow_builder` `FlowController<T>` |

It uses a global locator, `final _getIt = GetIt.I;`, with the comment "Generally speaking, we shouldn't use a global service locator like that. However, we are in a utility package…". Core of `initState`:

```dart
_getIt.pushNewScope(scopeName: hashCode.toString());
_controller = FeatureFlowController<T>(widget.state);
_getIt.registerSingleton<FeatureFlowController<T>>(_controller);
final initializer = widget.flowInitializer;
_initFuture = initializer == null
    ? null
    : () async {
        await initializer.init(_getIt);
      }();
```

Lifecycle:
1. **Scope push.** A scope is pushed, named after the State's `hashCode`, "so we can have multiple instances of the same feature".
2. **Controller registration.** The controller is registered as a singleton, so the feature can get it from GetIt.
3. **Feature DI.** The feature's initializer runs into the new scope, which "encapsulate[s] the DI configuration of a feature in a feature package".
4. **Build.** It builds `ColoredBox` (the scaffold background) → `FutureBuilder(_initFuture)` → `SizedBox()` until done → `FlowBuilder<T>(controller: …, onGeneratePages: (flow, _) => widget.onGeneratePages(flow).map((page) => MaterialPage(child: page)).toList())`.
5. **Dispose.** It calls `dropScope(hashCode.toString())`, then `_controller.dispose()`.

Defects, all **(inferred)**:
- **The null-future case never builds.** With no `flowInitializer`, `_initFuture` is null, so `FutureBuilder` stays in `ConnectionState.none` and the flow renders `SizedBox()` forever.
- **Initializer errors are swallowed.** A failed future still reaches `done` and builds the flow.
- **Scopes are one global stack, not tied to the widget tree.** Flows that sit side by side (tabs) shadow each other, and a lazily created bloc resolves from whichever scope is on top.
- **Pages carry no metadata.** `MaterialPage` has no `key`, `name` or `arguments`, so there are no route names for analytics or restoration.

### 3.3 Feature side: Marvel Characters [navigation › Marvel Characters]
- **Two screens.** `MarvelCharactersPage` is always shown, so it is "not tracked in the flow's state". `CharacterDetailsPage(character:)` lives in `lib/src/presentation/character_details_page.dart`: a `Scaffold` with `AppBar(title: Text(character.name))` and a TODO body.
- **Flow state.** `lib/src/flow/marvel_characters_flow_state.dart` holds `@freezed class MarvelCharactersFlowState` with one field, `MarvelCharacter? selectedCharacter`, and `part '….freezed.dart'`.
- **Pro-tip: "prefer plain models over unions".** Don't use one subclass per screen: "Thinking in terms of screens can tie your state to the UI structure… Treat screens as implementation details."
- **Flow.** `lib/src/flow/marvel_characters_flow.dart`:

```dart
class MarvelCharactersFlow extends StatelessWidget {
  const MarvelCharactersFlow({super.key});

  @override
  Widget build(BuildContext context) => FeatureFlow<MarvelCharactersFlowState>(
        flowInitializer: MarvelCharactersDIInitializer(),
        state: const MarvelCharactersFlowState(),
        onGeneratePages: (state) => [
          MarvelCharactersPage(),
          if (state.selectedCharacter != null)
            CharacterDetailsPage(character: state.selectedCharacter!),
        ],
      );
}
```

- **Event.** `MarvelCharactersEvent.openCharacter(MarvelCharacter)` creates the private `_OpenMarvelCharactersEvent`. This is a hand-written sealed class, not freezed [feature › Presentation].
- **Bloc.** `MarvelCharactersBloc` gains the constructor dependency `FeatureFlowController<MarvelCharactersFlowState> _controller`. Its `_onOpen` calls `_controller.update((state) => state.copyWith(selectedCharacter: event.character))`, so navigation is a side effect of a bloc event.
- **UI.** `CharacterItem` wraps its card in `InkWell(onTap: () => context.read<MarvelCharactersBloc>().add(MarvelCharactersEvent.openCharacter(character)))`.
- **Barrel.** `lib/marvel_characters.dart` now exports only `src/flow/marvel_characters_flow.dart`. The page and the DI initializer are hidden.
- **Folders.** A new `lib/src/flow/` folder appears beside the feature-level `di`, `domain`, `navigator` and `presentation` [feature › structure].
- **Unstated steps (inferred):**
  - The `feature_flow` dependency is never added to the feature's pubspec.
  - Re-running codegen is never mentioned, but `freezed` must generate the flow-state part, and `injectable` must regenerate `di_initializer.config.dart` for the bloc's new parameter.
  - The controller is not an injectable registration. `FeatureFlow` registers it at runtime, in the same scope, before the injectable initializer runs.

### 3.4 How features stay independent
- **Dependencies.** Features depend only on utilities [intro › Project Structure].
- **Visibility.** Code under `lib/src` is package-private. Only barrel exports are visible, and "the less you export the better" [utility › tide_prelude].
- **Feature export.** A feature exports only its flow [navigation › Marvel Characters].
- **Cross-feature navigation.** "No feature should know about another feature. When we need to navigate from one feature to another, we create a navigator class that will be defined in the feature, and implemented on the application level" [feature › structure].
- **What's not specified.**
  - The navigator's shape, its registration and its location are never given.
  - No shared "navigation contracts" utility exists.
  - Contracts belong to the *calling* feature (dependency inversion), and the app supplies implementations, probably through DI **(inferred)**.

### 3.5 App wiring [navigation › Application]
The barrel change breaks the app in two places:
- `di_initializer.dart` keeps only `MonitoringDIInitializer()` and `ApiClientDIInitializer()`. The snippet imports `package:monitoring/monitoring.dart`, a renamed package (§9.5).
- `BootPage` returns `const MarvelCharactersFlow()`.

From then on the app knows only two things about a feature: its flow widget, and the root-scope utilities the feature consumes **(inferred)**.

### 3.6 Arguments, results, deep links, nesting, back
| Topic | Articles | Notes |
|---|---|---|
| Arguments | The flow constructor is the contract [navigation › Two types of navigation]. `MarvelCharactersFlow` takes none | Constructor parameters would seed the initial `T state` **(inferred)** |
| Results | Not covered | `FeatureFlowController` hides `FlowController.complete`, and there is no `onComplete`, so a flow can't return a value **(inferred)** |
| Deep links | "Deep links to initiate specific flows" [ibid.] | Not implemented. Opening a details screen directly would need a flow argument **(inferred)** |
| Nested navigation | Implicit | `FlowBuilder` owns a nested `Navigator` under `MaterialApp(home:)`, so each flow is a nested stack **(inferred)** |
| Back | Not covered | `flow_builder` keeps a state history and reverts to the previous state on page pop (AppBar back, iOS swipe-back), which clears `selectedCharacter` **(inferred; verify)**. Leaving a flow's root page needs the root navigator, which isn't wired |
| External router | Bonus: "Implement proper external navigation with go_router or auto_route" | Not shown |

---

## 4. Testing

### 4.1 Philosophy [testing › intro]
- **Purpose.** Testing "validate[s] that the software under test works according to the specification", which can be an *engineering* spec (how the code works) or a *user* spec (behaviour).
- **User specs come first.** "For client app testing, user specification is much more important." Engineering specs "appear as a result of development and refactoring." Tide recommends covering behaviour first; the tutorial starts with unit tests only because they are easier to teach.
- **Requirements drive tests.** "Tests are not driven by implementation but by requirements." Sociable tests survive swapping bloc for `signals`, adding use cases, or dropping retrofit [testing › Problem With Images].

### 4.2 Strategy per layer
The articles never use the word "pyramid". The strategy has two tiers, split by layer:

| Layer | Kind | Entry point | Doubles | Tools |
|---|---|---|---|---|
| Utility | **Solitary** unit test, one-to-one with a class (`Monitoring`, `MarvelApiAuthInterceptor`, `Result`) | The class | `mocktail` mocks of external classes (`FirebaseCrashlytics`) | `test`, `mocktail` |
| Feature | **Sociable** BDD widget test | The **flow** widget, via `initFlow` | External utilities mocked (`MockMonitoring`); API stubbed at the Dio interceptor | `bdd_widget_test`, `flutter_test`, `mocktail`, `test_utils` |
| App | none described | — | — | — |
| Golden, integration, e2e | **not mentioned** (no `golden_toolkit`, `alchemist`, `integration_test` or `patrol`) | — | — | — |

Sources: [testing › Solitary Unit Tests; › Sociable Feature Tests; › Feature Testing].

- **The rule:** "you shouldn't mock any internal classes, only external dependencies (via mocktail) and API responses (via interceptor)" [testing › Feature Testing, bonus 4].
- **The rationale,** following Fowler's [UnitTest](https://martinfowler.com/bliki/UnitTest.html): utilities are reusable code with engineering requirements, so they get solitary tests. Features carry user behaviour, so they get sociable tests [ibid., bonus 5].

### 4.3 Solitary unit tests
- **Dependencies.** Add the dev dependencies `mocktail: ^1.0.4` and `test: ^1.16.5` to `monitoring` [testing › Setting Up Dependencies].
- **Mock pattern.** In `test/util/firebase_mock.dart`, write `class MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}` plus a factory, `createMockFirebaseCrashlytics()`, that stubs `log(any())` with `thenAnswer((_) async {})`. "By default, the mock will always do nothing without failing a test. We will follow the same strategy for all mocks" [testing › Creating Mocks].
- **Test shape.** `test/monitoring_test.dart` is a `group` with `late Monitoring sut`, every dependency built in `setUp`, and the comments `// Arrange`, `// Act`, `// Assert`, ending in `verify(...).called(1)` [testing › Writing a Unit Test].
- **Conventions.** The instance under test is always `sut`. Each test has one purpose, because several acts or asserts mean mixed scenarios. Keep the AAA comments "till it becomes natural".
- **Misprints.** The article writes `_sut`, and `crashlyticsMock('log: $event')` where it means `crashlyticsMock.log(...)` **(inferred)**.

### 4.4 The `test_utils` utility [testing › Creating a Test Utilities Package … Barrel File]
- **pubspec.** It lives at `utility/test_utils`, `version 0.0.1`. Its regular `dependencies` are `dio ^5.4.0`, `flutter`, `flutter_test` (sdk), `mocktail ^1.0.4`, `monitoring` and `tide_di`.
- **Usage.** Features consume it as a `dev_dependency`.
- **Undeclared import.** `get_it` is imported but not declared **(inferred)**.

| File | Symbol | Behaviour | Exported |
|---|---|---|---|
| `lib/src/feature_test_interceptor.dart` (the text says `test_test_interceptor.dart`) | `FeatureTestInterceptor extends Interceptor` | `mockRequest(path, json)` and `mockFailure(path, json)` are keyed by `options.path`. `onRequest` resolves with `jsonDecode(json)`, or rejects with `DioException(error: jsonDecode(json))`, or **throws** `No mocked request found for "<path>"` | yes |
| `lib/src/mock.dart` | `MockMonitoring`, `createMockMonitoring()` | Stubs `trackEvent(any())` to `Future.value()` | no |
| `lib/src/test_container.dart` | `TestContainer extends TideDIInitializer` | Registers singletons: the interceptor, a bare `Dio()` carrying it, and `createMockMonitoring()` | no |
| `lib/src/init_flow.dart` | `initFlow(WidgetTester, Widget Function() flowBuilder)` | Runs `initializeDIContainer([TestContainer()])`, then `pumpWidget(MaterialApp(home: flowBuilder()))` | yes |

- **The test container replaces the whole utility layer.** No `ApiClientDIInitializer` runs, so there is no base URL, no `MarvelApiAuthInterceptor` and no Firebase. The feature's own initializer still runs through `FeatureFlow`, so the real repository, the retrofit API and the bloc are all exercised **(inferred)**.
- **Isolation fix.** "The DI state will preserve in between test invocations." The fix makes the *production* `initializeDIContainer` in `tide_di` start with `await GetIt.instance.reset();` [testing › Flow Initializer].

### 4.5 Sociable BDD feature tests
- **Dependencies.** `marvel_characters` gets the dev dependencies `bdd_widget_test: ^1.7.4`, `flutter_test`, `mocktail: ^1.0.4` and `test_utils` (path) [testing › Feature Testing].
- **Data.** `test/util/data.dart` holds `final error = '{}';` and `final listOfCharacters = r'''…'''`, a raw string pasted from the Marvel docs "Try it out!" output. "Get the sample data from outside of the implementation (API specification, Swagger, samples, etc.), otherwise your tests will test what you have written and not what you were supposed to write" [testing › Testing Data].
- **Feature file.** `test/feature/marvel_characters.feature` [testing › Feature File]:

```gherkin
Feature: Marvel Characters

  Background:
    Given I am on the Marvel characters page

  Scenario: The Marvel characters flow should display a list of Marvel characters
    When backend responds with {'list of characters'}
    Then I see a list of Marvel characters

  Scenario: The Marvel characters flow should display an error message when the backend fails
    When backend responds with {'error'}
    Then I see an error message
```

- **Why Gherkin.** It answers "how to structure tests?", "when to extract code?" and "where to extract code?" with one question: "if you were writing tests in plain English, how would you structure the specification?" This holds even when developers are the only readers [ibid.].
- **Steps.** These live in `test/feature/step/` [testing › Updating Step Files]:
  - `i_am_on_the_marvel_characters_page.dart` calls `initFlow(tester, () => MarvelCharactersFlow())`, importing it from `src/`.
  - `backend_responds.dart` (the generator likely names it `…_with.dart` **(inferred)**) defines `backendRespondsWith(tester, String scenarioName)`. It takes `diContainer<FeatureTestInterceptor>()`, maps `'list of characters'` to `mockRequest('v1/public/characters', …)` and `'error'` to `mockFailure`, throws `ArgumentError` for anything else, then calls `pumpAndSettle()`.
  - `i_see_a_list_of_marvel_characters.dart` calls `iSeeText(tester, '3-D Man')`, the built-in step from `package:bdd_widget_test/step/i_see_text.dart`.
  - `a_see_an_error_message.dart` (a misprint) calls `iSeeText(tester, 'DioException [unknown]: null\nError: {}')`. The raw error text on screen is the subject of bonus 2.
- **The `pumpAndSettle` convention.** It is "a convention we agreed on", so that the test starts only after the backend is configured. Why it works **(inferred)**: during the Given step, `FeatureFlow` shows `SizedBox` while its initializer future resolves. The page, the bloc (which fires `load` in its constructor) and the HTTP call only appear on the next frames, inside the When step's `pumpAndSettle`. The ordering is implicit and fragile.

### 4.6 How BDD generation works
1. Write the `.feature` file.
2. Run `dart run build_runner build --delete-conflicting-outputs`. "Several files were generated for you. Let's change their content" [testing › Feature File].
3. `bdd_widget_test` then writes two kinds of file **(inferred from package behaviour; verify)**:
   - **The test file**, `test/feature/marvel_characters_test.dart`, next to the feature file. It is regenerated every build and excluded from analysis as "BDD tests" [utility › Linter].
   - **Step stubs** in `step/<snake_case_text>.dart`, one per missing step: a camelCase function with `/// Usage: <text>` and an `UnimplementedError` body. They are created once; developers own them afterwards. A `{'…'}` placeholder becomes a `String` parameter.
4. `Background` becomes a set-up call at the start of each scenario, and each `Scenario` becomes a `testWidgets` named after its title.

Approximate output (inferred, not shown in the article):

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter_test/flutter_test.dart';
import './step/i_am_on_the_marvel_characters_page.dart';
import './step/backend_responds_with.dart';
import './step/i_see_a_list_of_marvel_characters.dart';

void main() {
  group('''Marvel Characters''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await iAmOnTheMarvelCharactersPage(tester);
    }
    testWidgets('''The Marvel characters flow should display a list of Marvel characters''', (tester) async {
      await bddSetUp(tester);
      await backendRespondsWith(tester, 'list of characters');
      await iSeeAListOfMarvelCharacters(tester);
    });
  });
}
```

### 4.7 Images, running, coverage and best practices
- **Images.** `Image.network` fails under `flutter_test`. The options are `mocktail_image_network`, an `HttpOverrides` `HttpClient`, or `cached_network_image`, which "plays with tests nicely". The tutorial picks `cached_network_image: ^3.4.1` as a runtime dependency, with `CachedNetworkImage(imageUrl: character.thumbnail.url)` [testing › Problem With Images].
- **Running.** Run `flutter test --coverage` in each package; no workspace runner is mentioned **(inferred)**. The article points to the codewithandrea "Flutter Test Coverage Report in VSCode" tutorial for viewing coverage. Sociable tests covered "bloc, API, Repository, DI, and every other unimportant detail" [ibid.].
- **Best practices** [testing › Testing Best Practices]:
  - **Test only exported classes.** Unexported code that can't be reached that way is unused, so delete it.
  - **Coverage.** Aim for 100 % per package, with "the 90% threshold on CI to fail the PR". No CI system or gate tool is named.
  - **Run tests often.** The article links "Shortening Flutter test feedback cycle in VS Code".
  - **Size.** "If the test suite takes more than a few seconds to run, the package has too much functionality, so split it."

### 4.8 Layout and naming
```
utility/monitoring/test/monitoring_test.dart
utility/monitoring/test/util/firebase_mock.dart
utility/test_utils/lib/test_utils.dart            (barrel: interceptor + initFlow)
utility/test_utils/lib/src/{feature_test_interceptor,mock,test_container,init_flow}.dart
feature/marvel_characters/test/util/data.dart
feature/marvel_characters/test/feature/marvel_characters.feature
feature/marvel_characters/test/feature/marvel_characters_test.dart   (generated; inferred name)
feature/marvel_characters/test/feature/step/*.dart                  (stubs, then hand-edited)
```
- Test files are named `<subject>_test.dart`, and helpers go in `test/util/`.
- Mocks are `Mock<Type>`, built by `createMock<Type>()` factories that stub every method as a no-op.
- Step files and functions are the snake_case and camelCase forms of the step text.

---

## 5. Tech stack additions

| Package | Version | Where used | Purpose | Codegen? |
|---|---|---|---|---|
| `flow_builder` | `^0.1.0` | `utility/feature_flow` | Declarative internal navigation | No |
| `get_it` | `^7.6.4` | `feature_flow` (direct); `test_utils` (undeclared) | Scopes; test DI | No |
| `tide_di` | path | `feature_flow`, `test_utils`, app | `TideDIInitializer`, `initializeDIContainer`, `diContainer` | No |
| `freezed` / `freezed_annotation` | `^2.4.5` / `^2.4.1` [feature] | `MarvelCharactersFlowState` | Immutable state, `copyWith` | **Yes** |
| `injectable` / `injectable_generator` | `^2.3.2` / `^2.4.1` [feature] | Feature DI (the bloc's controller parameter) | `get_it` registrations | **Yes** |
| `flutter_bloc` | `^8.1.3` [feature] | The bloc dispatches navigation | State management | No |
| `go_router` | not stated | Suggested for external navigation | Routing | No (optional `go_router_builder`) **(inferred)** |
| `auto_route` | not stated | Tide production, external navigation [feature › Bonus exercise] | Routing | **Yes** (`auto_route_generator`) **(inferred)** |
| `test` | `^1.16.5` | `monitoring` dev | Test API and runner | No |
| `mocktail` | `^1.0.4` | `monitoring` dev, `test_utils`, feature dev | Mocks without codegen | **No** |
| `flutter_test` | sdk | `test_utils` (regular dependency), feature dev | Widget tests | No |
| `bdd_widget_test` | `^1.7.4` | feature dev | Gherkin → widget tests; built-in steps | **Yes** |
| `build_runner` | `^2.4.7` [utility, feature] | Feature packages | Runs generators | — |
| `dio` | `^5.4.0` | `test_utils` | `Interceptor`, `DioException` | No |
| `cached_network_image` | `^3.4.1` | Feature (runtime) | Test-friendly, cached images | No |
| `mocktail_image_network`, `signals` | not stated | Mentioned only | Alternatives | No |
| `feature_flow`, `test_utils` | path, `0.0.1` | Utility tier | In-house packages | No |

---

## 6. Code generation in the app, navigation and tests

| # | Generator | Input | Output | Lifecycle | Source |
|---|---|---|---|---|---|
| 1 | `freezed` | `@freezed MarvelCharactersFlowState` + its `part` directive | `lib/src/flow/marvel_characters_flow_state.freezed.dart` (`_$MarvelCharactersFlowState`, `copyWith`, `==`, `toString`). No `.g.dart`, because there is no `fromJson` | Regenerated | [navigation › Marvel Characters] |
| 2 | `injectable_generator` | `@injectable MarvelCharactersBloc` with its new `FeatureFlowController<MarvelCharactersFlowState>` parameter; `@injectableInit` | `lib/src/di/di_initializer.config.dart`, resolving `gh<FeatureFlowController<…>>()` at runtime from the flow scope **(inferred)** | Regenerated. One pass per file, then one aggregate pass over the whole package **(inferred)** | [navigation; feature › DI] |
| 3 | `bdd_widget_test` | `test/feature/*.feature` | `test/feature/<name>_test.dart` | Overwritten on every build; analyzer-excluded | [testing › Feature File; utility › Linter] |
| 4 | `bdd_widget_test` (scaffolding) | Steps that have no file yet | `test/feature/step/<step>.dart` stubs | Written **once**, then hand-owned source. Probably written outside `build_runner`'s declared outputs **(inferred; verify)** | [testing › Updating Step Files] |
| 5 | The same command also re-runs `json_serializable`, `retrofit_generator`, `freezed` and `injectable_generator` across the feature | Models, API and DI | `.g.dart`, `.freezed.dart`, `.config.dart` | One `build_runner build` runs every builder in the package | [feature] |
| 6 | `flutter test --coverage` | A test run | `coverage/lcov.info` (an artifact) | Per run | [testing › Problem With Images] |

- **No codegen in:**
  - the app (it has no `build_runner`)
  - `feature_flow` and `test_utils`
  - `mocktail`, as opposed to `mockito`'s `@GenerateMocks` **(inferred)**
- **Scaffolding, not part of the build:**
  - `mason_cli` templates for DI initializers [feature › DI]
  - the optional `barrel_files` generator [utility › tide_prelude]
- **Committed?** No article says. The analyzer excludes generated files, which proves they live in the source tree, but says nothing about git. **The Bazel design must decide this.**
- **Bazel-relevant facts (inferred):**
  - **BDD test generation is a clean 1:1 transform.** `.feature` → `_test.dart` maps onto one action or macro per file, followed by a test target.
  - **Stub scaffolding isn't hermetic.** It writes into the source tree, so it must stay a developer tool (`bazel run`).
  - **injectable aggregates the whole package.** Its `.config.dart` depends on every annotated file there, which hurts caching.
  - **`--delete-conflicting-outputs` assumes source-tree outputs.** Under Bazel, choose between outputs in `bazel-out` and committed outputs guarded by a freshness (diff) test.

---

## 7. Homework and bonus exercises

| Article | Exercises |
|---|---|
| Application [application › Bonus exercise] | (1) Handle initialization failure. (2) Handle initialization that takes too long. (3) Consider `--dart-define-from-file` instead of `--dart-define`s |
| Navigation [navigation › Feature flow; › Bonus exercises] | (1) Re-implement `feature_flow` with `auto_route`, or with Navigator 2.0, using `flow_builder` as reference. (2) Build external navigation with `go_router` or `auto_route`. (3) Complete `CharacterDetailsPage` |
| Testing, unit [testing › Writing a Unit Test] | (1) What tests are missing? (2) Why Arrange-Act-Assert, and when does it fail? (3) Read the `mocktail` source. (4) Unit-test every other utility |
| Testing, feature [testing › Feature Testing] (numbered 1 to 5 with "5" twice) | (1) Map each feature line to the generated Dart. (2) Fail a test for a friendlier error message, then fix it. (3) Pros and cons of text assertions, and alternatives. (4) Add the missing tests, mocking only external dependencies and the API. (5) Why unit tests for utilities and sociable tests for features? (6) Given-When-Then versus Arrange-Act-Assert |
| Related [feature › Bonus exercise] | Watch the Tide BDD and widget-test playlist. Real apps use `flow_builder` (internal) and `auto_route` (external) |

---

## 8. Diagrams

### 8.1 `project-miniclient-navigation-1.png` [navigation › Two types of navigation]
- **Layout.** A hand-drawn, Excalidraw-style sketch. Its caption reads "External Navigation orchestrates features. Internal Navigation — screens inside a feature." A full-width yellow bar labelled **External Navigation** sends four downward arrows to **Feature 1** (green), **Feature 2** (blue), a bare "…", and **Feature N** (blue).
- **Inside each feature.** Each feature box holds an **Internal Navigation** box with a vertical line that fans out to its screens:
  - Feature 1: Screens 1–3
  - Feature 2: Screens 1–2
  - Feature N: Screen 1, "…", Screen N
- **Meaning.** External navigation targets *features*, never screens. Each feature's internal navigator alone decides which screens exist and in what order, and features have different numbers of screens. The green probably marks the example feature, but the article doesn't say **(inferred)**.

### 8.2 `project-miniclient-testing-1.png` [testing › intro]
- **Row 1.** A blue **Solitary Test** box points to a yellow **Utility class** box: one test, one class.
- **Row 2.** A blue **Sociable Test** box points to a green **Feature Flow** box. From there one branch runs right to **Widget**, then **Bloc**, then **API**, and a second branch runs diagonally down to another **Widget**. Those boxes are white.
- **Meaning.** A sociable test enters only through the flow, the feature's public entry point, and exercises the real chain behind it: several pages, the bloc and the API. Only the outer edge is replaced, at the Dio interceptor **(inferred)**. The second Widget most likely stands for another page of the flow, such as `CharacterDetailsPage` **(inferred)**. There is no colour legend.

---

## 9. Gaps and ambiguities an enterprise implementation must decide

### 9.1 Navigation
1. **External router.** Choose `go_router` (no codegen) or `auto_route` (codegen; Tide's choice), and design route guards and type safety.
2. **Navigator contracts.** The navigator contract is named but not specified [feature › structure]. Decide its naming, location (`lib/src/navigator/`, exported), registration and how it scales. One app implementation per contract, across 100+ modules, may be too much.
3. **Flow results.** Pick a mechanism: callbacks, a `Future<R>` from a push, or exposing `onComplete`.
4. **Deep links and restoration.** Map URLs to a flow plus its initial state. Decide on state restoration, and on route names for analytics.
5. **Back behaviour.** Specify and test back at a flow's root, `PopScope` and confirm-on-exit, and iOS swipe-back inside nested navigators. Re-check `flow_builder` against Flutter 3.41, since Navigator's pop API changed after 3.16 **(inferred)**.
6. **Fix the `FeatureFlow` defects** listed in §3.2.
7. **Modals.** Decide how bottom sheets and dialogs fit into flow state. They are named as alternatives [navigation › Two types of navigation] but not modelled.

### 9.2 DI and app
1. **Boot.** Define the failure, timeout and retry behaviour.
2. **Reset placement.** `GetIt.reset()` now runs in *production* initialization. Decide whether it should move to test setup.
3. **Root versus flow scope.** Decide which registrations belong in each.
4. **Configuration.** Dart-defines are read deep inside a utility. Set a configuration strategy.

### 9.3 Testing
1. **Missing kinds.** Golden, e2e, app-level and accessibility tests, CI pipeline and coverage tool are all absent.
2. **`FeatureTestInterceptor` is too narrow.** It matches by path only, ignoring method, query and body. It has no response sequences (pagination, retry), no latency or status codes, and throws on unmocked paths.
3. **`test_utils` hides too much.** It exports neither `MockMonitoring` nor `TestContainer`, so a feature can't verify monitoring or add doubles. The container is monolithic.
4. **Bare test app.** `initFlow` uses a bare `MaterialApp`, without the app theme or a platform override.
5. **Hidden ordering.** Tests rely on the stub-then-`pumpAndSettle` ordering (§4.5).
6. **Shared steps.** Common steps need a home across features. `bdd_widget_test` supports external steps through `build.yaml` **(inferred; verify)**.
7. **Brittle assertions.** Asserting on raw text (bonus 3) breaks easily. Decide on keys or semantics labels.
8. **Generated code.** Decide whether generated code counts toward coverage, and whether generated files are committed (§6).
9. **Versions.** The 2024 pins (`flow_builder 0.1`, `get_it 7`, `bdd_widget_test 1.7`, freezed 2) need re-pinning. Freezed 3, for instance, changed class syntax **(inferred)**.

### 9.4 Process
The tutorial starts from the engineering spec, while practice is behaviour-first [testing › intro]. We should state which we follow.

### 9.5 Misprints and inconsistencies
| Item | Where |
|---|---|
| `tide_monitoring` with `log()` [utility, application] versus `monitoring` with `trackEvent()` [navigation, testing]. The bloc calls `log`, which `MockMonitoring` doesn't stub, so the error scenario would crash under mocktail unless the method was renamed **(inferred)** | Across articles |
| `prelude` [testing] versus `tide_prelude` [utility] | testing › Solitary Unit Tests |
| `_sut` versus `sut`; `crashlyticsMock(...)` should be `.log(...)` | testing › Writing a Unit Test |
| `test_test_interceptor.dart` versus the imported `feature_test_interceptor.dart` | testing › Mocking Networking Requests |
| `a_see_an_error_message.dart`; `backend_responds.dart` | testing › Updating Step Files |
| The `feature_flow` dependency is never added to the feature | navigation › Marvel Characters |

---

## 10. Implications for our project

Constraints:
- No real Marvel API: `mocked_backend` supplies the data ([ADR-0005](../../adr/0005-mocked-backend-module.md)).
- iOS-only verification ([ADR-0006](../../adr/0006-verification-strategy.md) §7).
- A Bazel build with `ai_rules_dart` / `ai_rules_flutter`.
- 100+ modules and 500k to 1M LOC.
- Given/When/Then ACs map to tests.

| Tide element | Carry-over | Why / risk |
|---|---|---|
| **Three tiers + import rules** | Adopt them, enforced by Bazel `visibility`: features see `//utility/...` only; only `//app` sees features | Conventions erode at 100+ modules, but a visibility error can't be ignored |
| **Barrel = public API, `src/` private** | Expose only the barrel from each `lib` target, which makes "test only exported API" enforceable | [testing › Testing Best Practices] |
| **Thin app** | It holds bootstrap, root DI (utilities only), the external router and navigator implementations. No business logic | It is the one target that depends on everything, so keep it small |
| **`TideDIInitializer` list** | Keep it. The root list holds the utilities plus a `mocked_backend` initializer (or a real adapter) chosen by configuration. Features initialize through their flows | Swapping the backend is then a one-line app change ([ADR-0005](../../adr/0005-mocked-backend-module.md) §2) |
| **BootPage** | Keep it, and add error, retry and timeout states as ACs backed by widget tests | Mock failure injection makes these deterministic |
| **dart-defines / launch.json** | No API keys needed. Use `--dart-define-from-file` for environment (mock latency, failure injection). `bazel run` targets replace `launch.json`. Verify that `ai_rules_flutter` passes defines | Unknown rule support makes this a T-0004 spike item |
| **Flow as the only feature export** | A hard rule: one or more `*Flow` widgets per feature, whose constructors (inputs plus result callbacks) are the contract | One stable entry point per BDD test and a tiny API per Bazel target |
| **`feature_flow`** | Adopt it, fixed: build without an initializer, surface initialization errors, add results, give pages names and keys. Re-validate `flow_builder` on Flutter 3.41, or write a small Navigator 2.0 equivalent | The published version has blocking defects (§3.2) |
| **Per-flow `get_it` scope** | Keep scoping. Either forbid side-by-side flows of one type, or move to tree-scoped DI | Global scope stacks fail with tabs |
| **The bloc updates the flow controller** | Keep it. Navigation is state, which ACs test through the UI ("When I tap X, Then I see details") | Fits sociable BDD |
| **External navigation** | Prefer `go_router` or a plain Navigator wrapper over `auto_route`, which adds a generator. Cross-feature navigators become abstract classes in the *calling* feature's `lib/src/navigator/`, implemented in `//app` and registered in root DI | Keeps features independent and limits codegen. Watch the app's growth |
| **Solitary unit tests** | Keep `test` + `mocktail`, AAA, `sut` and no-op `createMock*()` factories. `mocked_backend` is a utility with its own solitary tests | ADR-0006 L1 |
| **Sociable BDD (`bdd_widget_test`)** | Make it the default L2. **One AC = one Scenario, with the AC ID in the title** (`Scenario: T-0042-AC1 shows the character list`), so the generated `testWidgets` name carries the ID, as ADR-0006 §1 requires | The ACs are already Gherkin, which gives direct traceability |
| **`FeatureTestInterceptor` + JSON** | Replace it with `mocked_backend` in-process: the test container registers it with zero latency and scenario-selected fixtures or failures. If the transport is Dio, a `mocked_backend` `HttpClientAdapter` serves the app, the tests and e2e alike | One fixture source of truth; pagination and failures the Tide stub can't do |
| **Data from outside the implementation** | Author fixtures against T-0007's documented contract, never derived from feature models | Same anti-self-confirmation principle as ADR-0006 §3 |
| **`test_utils`** | A `testonly` Bazel library exporting the container, mocks, `initFlow` (with our theme and `TargetPlatform.iOS`) and shared Gherkin steps | Avoids re-implementing "Given I am logged in" in 100 features |
| **Images** | `mocked_backend` serves bundled placeholder assets, so tests load no network images | Removes the `Image.network` test failure |
| **Coverage** | Keep ADR-0006's ≥ 80 % (domain, data, mock) as the floor, and consider Tide's 90 % per package once BDD covers features. Decide whether to exclude generated code in `lcov` | Bazel `coverage` merges per target |
| **"Split if tests take more than a few seconds"** | Adopt it as a module-size heuristic | Aligns with Bazel caching |
| **Goldens and e2e (absent at Tide)** | Add L3 goldens (macOS, real fonts, iOS; F-0004) and L4 `integration_test` journeys on the simulator, possibly reusing the Gherkin steps through `bdd_widget_test`'s configurable test method **(inferred; verify)** | ADR-0006 requires both, and Tide gives no guidance |
| **Codegen under Bazel** | **Decide in T-0004:** commit generated files plus a freshness test, or generate them in actions. For BDD, a `bdd_test_suite(features = glob(...))` macro generates `_test.dart`, and stub scaffolding stays a `bazel run` tool. Check whether `ai_rules_dart` supports `build_runner` or `source_gen` at all. If not, prefer codegen-free choices (`mocktail`, `go_router`, hand-written initializers instead of `injectable`) | This is the largest migration risk. `injectable`'s package-wide aggregation and stub writes are the hard parts |
| **iOS-only** | BDD and widget tests run on the macOS host (no simulator), with `TargetPlatform.iOS` set in `initFlow` (Cupertino transitions, swipe-back). Only L4 and L5 use simulators (ADR-0006 §6) | Keeps the per-task loop fast |

**Suggested follow-ups (TL to file):**
- a navigation ADR (flows plus navigator contracts)
- a Bazel × `build_runner` spike (`bdd_widget_test`, `freezed`, `injectable`)
- `feature_flow` hardening
- a `test_utils` task with shared steps and a `mocked_backend` test container
