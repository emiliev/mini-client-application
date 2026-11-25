# F-0033: Kit fixes behind the `characters_list` workarounds (non-listening `di`, `provide:`, the copyWith barrel, the base URL)

- **Date:** 2026-11-25
- **Author:** crew: Engineer (T-0034)
- **Type:** Library behaviour / bug root cause
- **Related:** T-0034, F-0031 (Part A fact 2, Part B facts 1, 2, 4, 11), F-0018, plan 01 §3.3 and §4.5, ADR-0007, R30

## Summary
The exemplar now has plan 01 §3.3's shape: `create: (context) => context.di<CharactersListBloc>()`, `provide:` and `localizationsDelegates:` on the flow, a freezed bloc state with the default `copyWith`, and `@GET('v1/characters')`. The kits changed, not the feature. None of this needed a rules patch.

## Facts
1. **`context.di` must not listen.** provider (under flutter_bloc 9.1.1) runs a lazy `create` in a lifecycle that never rebuilds and asserts on any inherited-widget dependency. `McFlowContext.di` and `debugResolveAll` now use `FlowScope.read` (`getInheritedWidgetOfExactType`). A flow's container never changes while its scope lives, so no rebuild is lost. `FlowScope.of` stays, listening, for code that wants to rebuild on a scope change (a Retry that opens a new container).
   - Test with a control: a listening probe below a swapped scope rebuilds, the `di` probe does not, and the bloc is created once (`T-0034-AC1`). Putting `FlowScope.of` back into `di` fails 3 tests.
2. **`provide:` runs before `flowInitializer`**, in the flow's recording container, so `debugResolveAll` sees it. The plan's signature is kept: `void Function(GetIt scope)`. A flow without it cannot resolve the type, and neither can the root.
3. **`localizationsDelegates:` is the feature's delegates only.** The flow appends `mcLocalizationsDelegates` (core strings plus Flutter's own), so a feature no longer imports `mc_l10n_core` just for that. `mc_feature_flow` now depends on `mc_l10n_core`; there is no cycle (`mc_l10n_core` has only Flutter deps). With an empty list the flow leaves `Localizations` as the host set it.
4. **The deep `copyWith` needs `$PagedStateCopyWith` in the barrel.** `mc_paging` now exports `show $PagedStateCopyWith, PagedState`. A freezed union or class that holds `PagedState<T>` compiles with the default `copyWith`, and `copyWith.page(...)` works. Without the export the library fails with `Type '$PagedStateCopyWith' not found` (negative control in the evidence). The generated bloc state is byte-identical to build_runner's with the three `$PagedStateCopyWith` references in it (`T-0032-AC6_matches_build_runner.sh`, 11 of 11). A freezed union has no `copyWith` of its own when its cases differ; the deep copy lives on the case type, which is private (R16).
5. **The base URL always ends with `/`.** Dio joins `baseUrl + path` as strings, so a slashless base fuses host and first path segment (`api.testv1`; a control test pins it).
   - `AppConfig.fromJson` appends the slash (`withTrailingSlash`), and the `AppConfig` constructor asserts it.
   - `createApiDio` asserts it as well, and the defaults (`defaultApiBaseUrl`, `MockBackend.createDio`, `McTestContainer.config`, `tool/bazel/config/*.json`) end with `/`.
   - **`AppConfig`'s constructor is no longer `const`.** `String.endsWith` is not allowed in a constant assert. The one const user was `McTestContainer.config`, now `static final`.
   - A leading-slash path still resolves when the base ends with `/` (Dio drops one slash), so the convention is enforced by `tool/checks/T-0034-AC4_relative_paths.sh`, which scans all hand-written Dart for `@GET('/…')` and has a negative control. It is a script, not a Bazel test, because a test cannot read other packages' sources. Wiring it into `mcgen check` is a follow-up.
6. **Flow-state test hook: `package:mc_feature_flow/testing.dart`, `flowStateOf<S>(BuildContext)`.** It reads the controller through the scope (`FlowScope.controller`), so it has no `flutter_test` dependency and ships in the production package. It throws `StateError` naming both types when the state is another type, and a `FlutterError` outside a flow. A feature keeps its state type private (R4), so a BDD step asks for `flowStateOf<dynamic>` and reads the fields it needs. That is dynamic access to the feature's own state, no longer to `mc_feature_flow` internals. A typed read would need the feature to export its state type for tests.
7. **`dart format` needs the workspace package config.** In a fresh worktree `fvm flutter pub get --offline` must run first; without it `analysis_options.yaml`'s `include: package:mc_analysis/...` does not resolve, the `formatter: trailing_commas: preserve` setting is lost, and `dart format utility feature` rewrites a dozen unrelated files.

## Evidence
`documents/evidence/T-0034/engineer/` (see the task's Outcome).

## Implications / actions
- Templates and buildgen: emit `context.di<T>()` in `create`, `provide:` for navigators, `localizationsDelegates:` with the feature's delegate only, bare `@freezed` for bloc states, relative retrofit paths.
- `app/wiring/app_core/test/boot_test.dart` (T-0033's area) asserts `dio.options.baseUrl == 'https://mock.mini-client.invalid'` over a config JSON without the slash; with the normalisation it is now `…invalid/`.
