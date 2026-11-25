# T-0034-AC5: no workaround markers in <origin/main>/feature/characters/characters_list

- Dart sources scanned: 37
- markers checked: 10

| Result | Detail |
|---|---|
| hits in the feature | F-0031 marker comment: <origin/main>/feature/characters/characters_list/lib/src/domain/api/characters_list_api.dart:14:/// land on the host (`…invalidv1/characters`, F-0031 B).
F-0031 marker comment: <origin/main>/feature/characters/characters_list/lib/src/presentation/page/character_preview_page.dart:28:    // Read in build, not in `create` (F-0031 B; see CharactersListPage).
F-0031 marker comment: <origin/main>/feature/characters/characters_list/lib/src/presentation/page/characters_list_page.dart:27:    // dependency in a callback provider forbids it in (F-0031 B).
F-0031 marker comment: <origin/main>/feature/characters/characters_list/lib/src/presentation/bloc/characters_list_state.dart:8:/// not export, and the library would not compile (F-0031).
copyWith: false on a bloc state: <origin/main>/feature/characters/characters_list/lib/src/presentation/bloc/characters_list_state.dart:9:@Freezed(copyWith: false)
FlowScope.of in feature code (the build-time container read): <origin/main>/feature/characters/characters_list/lib/src/presentation/page/character_preview_page.dart:29:    final flow = FlowScope.of(context).container;
FlowScope.of in feature code (the build-time container read): <origin/main>/feature/characters/characters_list/lib/src/presentation/page/characters_list_page.dart:28:    final flow = FlowScope.of(context).container;
container read into a local for create: <origin/main>/feature/characters/characters_list/lib/src/presentation/page/character_preview_page.dart:29:    final flow = FlowScope.of(context).container;
container read into a local for create: <origin/main>/feature/characters/characters_list/lib/src/presentation/page/characters_list_page.dart:28:    final flow = FlowScope.of(context).container;
leading-slash retrofit path: <origin/main>/feature/characters/characters_list/lib/src/domain/api/characters_list_api.dart:21:  @GET('/v1/characters')
hand-rolled Localizations.override in the flow: <origin/main>/feature/characters/characters_list/lib/src/flow/characters_list_flow.dart:38:  Widget build(BuildContext context) => Localizations.override(
navigator registered in a hand-written initializer: <origin/main>/feature/characters/characters_list/lib/src/flow/characters_list_flow.dart:73:      getIt.registerSingleton<CharactersListNavigator>(navigator);
dynamic read of a private flow widget: <origin/main>/feature/characters/characters_list/test/feature/util/characters_list_env.dart:52:    (w) => '${w.runtimeType}' == '_LivePage<CharactersListFlowState>',
dynamic .controller access: <origin/main>/feature/characters/characters_list/test/feature/util/characters_list_env.dart:56:  final dynamic controller = (tester.widget(page.first) as dynamic).controller; |
| negative control (planted marker) | tripped |

```
F-0031 marker comment: <origin/main>/feature/characters/characters_list/lib/src/domain/api/characters_list_api.dart:14:/// land on the host (`…invalidv1/characters`, F-0031 B).
F-0031 marker comment: <origin/main>/feature/characters/characters_list/lib/src/presentation/page/character_preview_page.dart:28:    // Read in build, not in `create` (F-0031 B; see CharactersListPage).
F-0031 marker comment: <origin/main>/feature/characters/characters_list/lib/src/presentation/page/characters_list_page.dart:27:    // dependency in a callback provider forbids it in (F-0031 B).
F-0031 marker comment: <origin/main>/feature/characters/characters_list/lib/src/presentation/bloc/characters_list_state.dart:8:/// not export, and the library would not compile (F-0031).
copyWith: false on a bloc state: <origin/main>/feature/characters/characters_list/lib/src/presentation/bloc/characters_list_state.dart:9:@Freezed(copyWith: false)
FlowScope.of in feature code (the build-time container read): <origin/main>/feature/characters/characters_list/lib/src/presentation/page/character_preview_page.dart:29:    final flow = FlowScope.of(context).container;
FlowScope.of in feature code (the build-time container read): <origin/main>/feature/characters/characters_list/lib/src/presentation/page/characters_list_page.dart:28:    final flow = FlowScope.of(context).container;
container read into a local for create: <origin/main>/feature/characters/characters_list/lib/src/presentation/page/character_preview_page.dart:29:    final flow = FlowScope.of(context).container;
container read into a local for create: <origin/main>/feature/characters/characters_list/lib/src/presentation/page/characters_list_page.dart:28:    final flow = FlowScope.of(context).container;
leading-slash retrofit path: <origin/main>/feature/characters/characters_list/lib/src/domain/api/characters_list_api.dart:21:  @GET('/v1/characters')
hand-rolled Localizations.override in the flow: <origin/main>/feature/characters/characters_list/lib/src/flow/characters_list_flow.dart:38:  Widget build(BuildContext context) => Localizations.override(
navigator registered in a hand-written initializer: <origin/main>/feature/characters/characters_list/lib/src/flow/characters_list_flow.dart:73:      getIt.registerSingleton<CharactersListNavigator>(navigator);
dynamic read of a private flow widget: <origin/main>/feature/characters/characters_list/test/feature/util/characters_list_env.dart:52:    (w) => '${w.runtimeType}' == '_LivePage<CharactersListFlowState>',
dynamic .controller access: <origin/main>/feature/characters/characters_list/test/feature/util/characters_list_env.dart:56:  final dynamic controller = (tester.widget(page.first) as dynamic).controller;
```

**FAIL T-0034-AC5-no-markers**
