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

/// Analytics settings (`analytics` in `config/<env>.json`, optional).
class AnalyticsConfig {
  const AnalyticsConfig({this.defaultConsent = 'unknown'});

  /// A missing `analytics` section, or a missing key, means `unknown`.
  ///
  /// A value of the wrong type (a number, a list) is treated as missing, never
  /// a crash at boot: the safe default is `unknown`.
  factory AnalyticsConfig.fromJson(Object? json) {
    final value = json is Map<String, dynamic> ? json['defaultConsent'] : null;
    return AnalyticsConfig(defaultConsent: value is String ? value : 'unknown');
  }

  /// The consent before the user has chosen: `unknown`, `granted` or
  /// `denied`. `dev` and `e2e` say `granted` so developers see events;
  /// release-like builds leave it `unknown`. `mc_analytics` reads it (a
  /// saved choice wins).
  final String defaultConsent;
}

/// [url] with a trailing `/` added when it has none. Real code, not an
/// assert: asserts are stripped in release builds.
String withTrailingSlash(String url) => url.endsWith('/') ? url : '$url/';

/// Typed per-environment configuration. Read once at boot (R13: no
/// dart-defines).
class AppConfig {
  AppConfig({
    required this.env,
    required this.backend,
    required String apiBaseUrl,
    required this.build,
    this.version,
    this.analytics = const AnalyticsConfig(),
  }) : apiBaseUrl = withTrailingSlash(apiBaseUrl);

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    env: json['env'] as String,
    backend: BackendConfig.fromJson(json['backend'] as Map<String, dynamic>),
    apiBaseUrl: json['apiBaseUrl'] as String,
    build: json['build'] as String,
    // Optional (T-0070): the settings index shows it when there is one.
    version: switch (json['version']) {
      final String v when v.isNotEmpty => v,
      _ => null,
    },
    analytics: AnalyticsConfig.fromJson(json['analytics']),
  );

  /// Parses the text of `app_config.json`.
  factory AppConfig.parse(String source) =>
      AppConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);

  final String env;
  final BackendConfig backend;

  /// Base URL of the API; the constructor adds a trailing `/` when it is
  /// missing, so it always ends with one and a retrofit path like
  /// `'v1/characters'` (relative, no leading `/`) lands under it. Dio joins
  /// `baseUrl + path` as strings. The mocked backend never contacts it.
  final String apiBaseUrl;
  final String build;

  /// The app's release version, as the settings index shows it (T-0070).
  /// Null when `version` is missing, empty or not a string.
  final String? version;
  final AnalyticsConfig analytics;
}
