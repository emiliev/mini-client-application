import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// The root services this flow's container forwards (R17): the parameter
/// types of every injectable constructor and `@factoryMethod` in the package,
/// minus what the package registers itself and what the flow provides
/// (`FeatureFlowController`, the navigator).
///
/// HAND-WRITTEN FOR NOW (as in library_reading_list_editor):
/// `test/flow_scope_test.dart` opens the flow over the production-shaped test
/// root and resolves every registration, so a missing import fails a test,
/// not the app.
const List<RootImport<Object>> authSignInRootImports = [
  RootImport<AuthApi>(),
  RootImport<Monitoring>(),
];
