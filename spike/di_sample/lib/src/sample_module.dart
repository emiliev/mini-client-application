import 'package:injectable/injectable.dart';

/// Values and async resources the sample gets from a module.
@module
abstract class SampleModule {
  @Named('appName')
  String get appName => 'mini-client';

  /// Resolved before `init` returns, so `init` is async.
  @preResolve
  Future<SampleSettings> settings() async => const SampleSettings(retries: 3);
}

/// Settings loaded at start-up.
class SampleSettings {
  const SampleSettings({required this.retries});

  final int retries;
}
