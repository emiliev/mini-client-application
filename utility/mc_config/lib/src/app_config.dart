import 'dart:convert';

/// Backend mock settings (`backend` in `config/<env>.json`).
class BackendConfig {
  const BackendConfig({
    required this.seed,
    required this.latency,
    required this.scenario,
  });

  factory BackendConfig.fromJson(Map<String, dynamic> json) => BackendConfig(
    seed: json['seed'] as int,
    latency: Duration(milliseconds: json['latencyMs'] as int),
    scenario: json['scenario'] as String,
  );

  final int seed;
  final Duration latency;
  final String scenario;
}

/// Typed per-environment configuration. Read once at boot (R13: no
/// dart-defines).
class AppConfig {
  const AppConfig({
    required this.env,
    required this.backend,
    required this.apiBaseUrl,
    required this.build,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    env: json['env'] as String,
    backend: BackendConfig.fromJson(json['backend'] as Map<String, dynamic>),
    apiBaseUrl: json['apiBaseUrl'] as String,
    build: json['build'] as String,
  );

  /// Parses the text of `app_config.json`.
  factory AppConfig.parse(String source) =>
      AppConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);

  final String env;
  final BackendConfig backend;

  /// Base URL of the API. The mocked backend never contacts it.
  final String apiBaseUrl;
  final String build;
}
