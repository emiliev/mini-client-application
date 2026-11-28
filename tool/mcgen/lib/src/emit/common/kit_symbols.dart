// The shared table of the symbols generated code takes from other packages
// (P-120 (b), F-0065 section 5.4), so an archetype never registers them by
// hand: `registerKitSymbols(ctx.symbols)` once, then `ref('McBloc')`.
//
// First-party kits are checked against their barrels: `test/kit_symbols_test`
// scans each barrel's export closure in the repo (barrel_scan.dart) and
// fails on a name the barrel does not export, so a renamed or dropped kit
// symbol breaks a test, not a generated module.
//
// Third-party symbols are the few the templates use; the generated modules'
// analysis (Bazel's dart_analyze aspect) is what checks them. Flutter and
// flutter_test are not here: a template knows whether a file needs
// `material.dart`, `widgets.dart` or `flutter_test.dart` and imports it
// explicitly (`DartLibrary.imports`), because one Flutter name is exported
// by several of its libraries.

import 'package:mcgen/src/core/ir/symbols.dart';

/// First-party barrel URI -> the names it exports that templates use.
const firstPartyKitSymbols = <String, List<String>>{
  'package:mc_api_client/mc_api_client.dart': ['ApiPage', 'apiCall'],
  'package:mc_api_errors/mc_api_errors.dart': [
    'ApiFailure',
    'ApiMalformed',
    'ApiOffline',
    'ApiServer',
    'ApiTimeout',
  ],
  'package:mc_bloc_kit/mc_bloc_kit.dart': [
    'FeatureFlowController',
    'McBloc',
    'McFailureState',
  ],
  'package:mc_di/mc_di.dart': [
    'McDIInitializer',
    'RootImport',
    'initializeDIContainer',
  ],
  'package:mc_ds_buttons/mc_ds_buttons.dart': [
    'McButton',
    'McButtonVariant',
    'McIconButton',
  ],
  'package:mc_ds_cards/mc_ds_cards.dart': ['McMediaCard'],
  'package:mc_ds_feedback/mc_ds_feedback.dart': [
    'McEmptyView',
    'McErrorView',
    'McLoading',
  ],
  'package:mc_ds_layout/mc_ds_layout.dart': ['McGap', 'McInsets'],
  'package:mc_ds_lists/mc_ds_lists.dart': ['McPagedGrid', 'McPagedList'],
  'package:mc_ds_media/mc_ds_media.dart': ['McImage', 'McMediaScope'],
  'package:mc_ds_navigation/mc_ds_navigation.dart': [
    'McAppBar',
    'McSectionHeader',
  ],
  'package:mc_feature_flow/mc_feature_flow.dart': [
    'FeatureFlow',
    'McFlowBackButton',
    'McFlowContext',
    'McFlowPage',
  ],
  'package:mc_feature_flow/testing.dart': ['flowStateOf'],
  'package:mc_fixtures_media/mc_fixtures_media.dart': [
    'BundledImageResolver',
    'placeholderSets',
  ],
  'package:mc_l10n_core/mc_l10n_core.dart': ['McL10nCoreL10n'],
  'package:mc_media/mc_media.dart': [
    'ApiImage',
    'AssetResolvedImage',
    'ImageVariant',
    'NetworkResolvedImage',
  ],
  'package:mc_mocked_backend/mc_mocked_backend.dart': [
    'MockBackend',
    'MockDomain',
    'canonicalJson',
    'defaultMockClock',
  ],
  'package:mc_monitoring/mc_monitoring.dart': ['Monitoring'],
  'package:mc_paging/mc_paging.dart': [
    'Page',
    'PagedState',
    'PagingController',
  ],
  'package:mc_prelude/mc_prelude.dart': ['Result'],
  'package:mc_test_utils/mc_test_utils.dart': [
    'BackendFailure',
    'McFixtureAssetBundle',
    'McFixtureSets',
    'McTestApp',
    'McTestSession',
    'initFlow',
    'mcPrecacheFixtureImages',
    'mcSettle',
    'mcTestWidgets',
  ],
};

/// Third-party library URI -> the names templates use from it.
const thirdPartySymbols = <String, List<String>>{
  'package:bloc/bloc.dart': ['Emitter'],
  'package:dio/dio.dart': ['Dio'],
  'package:flutter_bloc/flutter_bloc.dart': [
    'BlocBuilder',
    'BlocProvider',
    'MultiBlocProvider',
    'ReadContext',
  ],
  'package:freezed_annotation/freezed_annotation.dart': [
    'Freezed',
    'Implements',
    'JsonSerializable',
    'freezed',
  ],
  'package:get_it/get_it.dart': ['GetIt'],
  'package:injectable/injectable.dart': [
    'InjectableInit',
    'factoryMethod',
    'factoryParam',
    'injectable',
  ],
  'package:mocktail/mocktail.dart': [
    'Mock',
    'verify',
    'verifyNoMoreInteractions',
  ],
  'package:retrofit/retrofit.dart': [
    'DELETE',
    'GET',
    'PATCH',
    'POST',
    'PUT',
    'Query',
    'RestApi',
  ],
};

/// Registers every symbol of both tables in [table].
void registerKitSymbols(SymbolTable table) {
  for (final source in [firstPartyKitSymbols, thirdPartySymbols]) {
    source.forEach((uri, names) {
      for (final n in names) {
        table.external(n, uri);
      }
    });
  }
}
