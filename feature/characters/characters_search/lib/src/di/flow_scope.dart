import 'package:dio/dio.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_storage/mc_storage.dart';

/// The root services this flow's container forwards (R17): the parameter
/// types of every injectable constructor, `@factoryMethod` and module member
/// in the package, plus the screen tracker the flow's observer resolves,
/// minus what the package registers itself and what the flow provides
/// (`FeatureFlowController`, the navigator).
///
/// HAND-WRITTEN FOR NOW. Plan 01 §4.5 has `mcgen wire` derive this file from
/// the same analyzer input injectable reads, and `mcgen check` fail on drift
/// (Phase D). Until then `test/flow_scope_test.dart` opens the flow over the
/// production-shaped test root and resolves every registration, so a missing
/// import fails a test, not the app.
const List<RootImport<Object>> charactersSearchRootImports = [
  RootImport<AnalyticsTracker>(),
  RootImport<Dio>(),
  RootImport<FileStore>(),
  RootImport<Monitoring>(),
];
