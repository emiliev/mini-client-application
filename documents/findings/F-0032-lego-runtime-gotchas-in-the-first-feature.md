# F-0032: Run-time gotchas the first feature hit in plan 01's canonical code

- **Date:** 2026-11-25
- **Author:** crew: Engineer (T-0032)
- **Type:** Bug root cause / lesson
- **Related:** T-0032, plan 01 §3.3 and §4.5, R17, F-0018, F-0024, ADR-0007

## Summary
Plan 01 §3.3's code for the exemplar feature compiles in most places but fails at run time in three, and two kit APIs differ from what it assumes. Phase D's generators copy this package, so each item below is either fixed in the feature (and marked in the code) or needs a TL decision on a shared package. None is a codegen problem.

## Facts
1. **`context.di<T>()` inside `BlocProvider.create` throws.** `McFlowContext.di` goes through `FlowScope.of`, which calls `dependOnInheritedWidgetOfExactType`. provider (under flutter_bloc 9.1.1) locks dependencies while a lazy `create` runs and asserts: "Tried to listen to an InheritedWidget in a life-cycle that will never be called again". On unmount the provider then fails again (`type 'Null' is not a subtype of type 'CharactersListBloc'`). Plan 01's `create: (context) => context.di<CharactersListBloc>()` therefore fails on every page.
   - **In the feature:** the page reads `FlowScope.of(context).container` in `build` (a legal dependency) and `create` calls that container.
   - **Proper fix (TL, `mc_feature_flow`):** `di` and `debugResolveAll` use `getInheritedWidgetOfExactType<FlowScope>()` (no dependency; the flow's container never changes while the scope lives). The plan's one-liner then works as written.
2. **A relative retrofit path drops the API version.** Dio joins `baseUrl + path` as strings, and `AppConfig.apiBaseUrl` is `https://mock.mini-client.invalid` (no trailing slash). So `@GET('v1/characters')` requests host `mock.mini-client.invalidv1`, path `/characters`. The harness caught it as `Unmatched request GET /characters`. The feature uses `@GET('/v1/characters')`. Either templates use a leading `/`, or `apiBaseUrl` ends with `/` (TL: config is app-wide).
3. **`McTestApp` had no Flutter localisations.** With `locale: de`, `MaterialApp` reports "This application's locale, de, is not supported by all of its localization delegates" (Material and Cupertino) and the test fails on that report. The flow's own `Localizations.override` cannot help, because the report comes from `MaterialApp` itself. `McTestApp` now installs `GlobalMaterialLocalizations.delegates` (`mc_test_utils`, plus `flutter_localizations`; test `T-0032-AC4 initFlow in de has Flutter's German strings`). The production app shell needs the same when it gains l10n.
4. **`FeatureFlow` has no `provide:` and no `localizationsDelegates:`** (plan 01 §3.3 and §4.5 list both; T-0022 built neither).
   - The flow registers the navigator inside its `flowInitializer` (`McDIInitializer` that registers it, then runs `CharactersListDIInitializer`).
   - The flow wraps itself in `Localizations.override` with its delegates plus `mcLocalizationsDelegates`.
   - Both are marked in `characters_list_flow.dart`. Adding the two parameters to `FeatureFlow` would let the template match the plan.
5. **`McFailureState` needs fields named `error` and `stackTrace`.** Plan 01's `@Implements<McFailureState>() failure(ApiFailure failure)` does not compile against `mc_bloc_kit`. The state is `failure(ApiFailure error, {StackTrace? stackTrace})`.
6. **The mocked backend has no response wrapper.** `GET /v1/characters` returns the page envelope itself (`offset`, `limit`, `total`, `count`, `results`), so `mc_api_client` gains `ApiPage<T>` only. An `ApiResponse<T>` (`code`, `status`, `data`, the T-0027 spike's model of Tide's `MarvelResponse`) would match no response; the API returns `ApiPage<CharacterDto>`. If the contract should wrap responses, that is a contract change in `mc_fixtures_characters` (TL / PO).
7. **Hosts must provide `McMediaScope` and an asset bundle.** `McImage` throws without a `McMediaScope` (T-0031). Feature tests wrap the flow in `McMediaScope(resolver: BundledImageResolver())` plus `DefaultAssetBundle(McFixtureAssetBundle())` (`charactersTestHost`). The app root does the same in T-0033.
8. **flutter_bloc and mocktail were not in the lock.** Both are in ADR-0007's stack. Root `pubspec.lock` now has flutter_bloc 9.1.1 (with provider 6.1.5+1 and nested 1.0.0) and mocktail 1.0.5; nothing else moved. F-0024 item 1's hand-written `MockMonitoring` stays; navigator mocks are mocktail `Mock`s.

## Evidence
- 1: the first BDD run (all 15 scenarios failed with the provider assertion); the stack shows `FlowScope.of` ← `McFlowContext.di` ← `CharactersListPage.build.<closure>` ← `_CreateInheritedProviderState.value`.
- 2: the second run: every scenario failed with `Unmatched request GET /characters`.
- 3: the third run: only the German scenario failed, on the delegates warning.

## Implications / actions
- TL decisions: `mc_feature_flow` (`di` without a dependency, `provide:`, `localizationsDelegates:`); `apiBaseUrl` trailing slash or leading-slash paths; `ApiResponse<T>` or not; `mc_paging` exporting `$PagedStateCopyWith` (F-0031).
- Until those land, buildgen and the mason bricks copy the feature's workarounds, which are marked in the code with this finding's number.
