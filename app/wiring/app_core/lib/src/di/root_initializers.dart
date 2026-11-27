import 'dart:io';

import 'package:app_core/src/di/mocked_backend_di_initializer.dart';
import 'package:app_core/src/router/router_ref.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_feature_flags/mc_feature_flags.dart';
import 'package:mc_formatters/mc_formatters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';

/// The root DI list, in order (plan 01 §3.4). Utilities first, then the
/// wirings (navigator implementations). Features initialise themselves in
/// their flows, never here.
///
/// The shared `Dio` (mc_api_client) runs on the mocked backend's adapter
/// (ADR-0005). The session needs storage and the event bus, so both come
/// before it (plan 01 lists the bus later; T-0039), and api auth goes on the
/// shared Dio, so it comes right after the API client. The formatters' locale
/// data loads where plan 01 has `L10nCoreDIInitializer` (T-0041), last before
/// the wirings. Analytics (T-0053) comes right after storage, not right after
/// monitoring as plan 01 has it: it keeps the consent choice in `mc_storage`.
/// The feature flags (T-0052) go right after api auth, as plan 01 orders them:
/// they fetch through the shared `Dio` with the bearer, and they register at
/// once with saved or default values (the first fetch runs in the background,
/// so boot never waits on the network). The appearance (T-0063, ADR-0013)
/// comes after the flags for the same reasons: it syncs through the shared
/// `Dio` with the bearer, and registers at once with the device's saved
/// values. Not in the list yet, because their
/// package does not exist: l10n core.
List<McDIInitializer> rootInitializers({
  required ConfigSource config,
  required Directory storageDirectory,
  List<MonitoringSink>? monitoringSinks,
  List<AnalyticsSink>? analyticsSinks,
  List<MockDomain> mockDomains = const [],
  RouterRef? routerRef,
  List<McDIInitializer> wirings = const [],
}) {
  final backendAdapter = MockBackendHttpAdapter();
  return [
    ConfigDIInitializer(config),
    MonitoringDIInitializer(sinks: monitoringSinks),
    StorageDIInitializer(storageDirectory),
    AnalyticsDIInitializer(sinks: analyticsSinks),
    const EventBusDIInitializer(),
    const SessionDIInitializer(),
    MockedBackendDIInitializer(adapter: backendAdapter, domains: mockDomains),
    ApiClientDIInitializer(adapter: backendAdapter),
    const ApiAuthDIInitializer(),
    const FeatureFlagsDIInitializer(),
    const AppearanceDIInitializer(),
    const FormattersDIInitializer(),
    if (routerRef != null) RouterDIInitializer(routerRef),
    ...wirings,
  ];
}

/// The app's storage directory on iOS, from `dart:io` alone (no
/// path_provider plugin): `<data container>/Library/Application Support/
/// mc_storage`. `Directory.systemTemp` is the container's `tmp/`.
Directory appStorageDirectory() {
  final container = Directory.systemTemp.parent.path;
  return Directory('$container/Library/Application Support/mc_storage');
}
