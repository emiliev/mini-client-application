import 'dart:io';

import 'package:app_core/src/di/mocked_backend_di_initializer.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_storage/mc_storage.dart';

/// The root DI list, in order (plan 01 §3.4). Utilities first, then the
/// wirings (navigator implementations). Features initialise themselves in
/// their flows, never here.
///
/// The shared `Dio` (mc_api_client) runs on the mocked backend's adapter
/// (ADR-0005). Not in the list yet, because their packages do not exist:
/// analytics, session, api auth, feature flags and l10n core.
List<McDIInitializer> rootInitializers({
  required ConfigSource config,
  required Directory storageDirectory,
  List<MonitoringSink>? monitoringSinks,
  List<MockDomain> mockDomains = const [],
  List<McDIInitializer> wirings = const [],
}) {
  final backendAdapter = MockBackendHttpAdapter();
  return [
    ConfigDIInitializer(config),
    MonitoringDIInitializer(sinks: monitoringSinks),
    StorageDIInitializer(storageDirectory),
    MockedBackendDIInitializer(adapter: backendAdapter, domains: mockDomains),
    ApiClientDIInitializer(adapter: backendAdapter),
    const EventBusDIInitializer(),
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
