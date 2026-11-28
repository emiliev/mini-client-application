import 'package:mc_config/mc_config.dart';

/// What "About" shows: the app's version and build, and the seed of the
/// mocked backend (the app has no other backend). Read from the app's
/// config once.
final class AboutInfo {
  const AboutInfo({required this.build, required this.seed, this.version});

  factory AboutInfo.fromConfig(AppConfig config) => AboutInfo(
    version: config.version,
    build: config.build,
    seed: config.backend.seed,
  );

  /// The release version, or null when the config names none.
  final String? version;
  final String build;
  final int seed;

  @override
  bool operator ==(Object other) =>
      other is AboutInfo &&
      other.version == version &&
      other.build == build &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(AboutInfo, version, build, seed);

  @override
  String toString() => 'AboutInfo($version, $build, $seed)';
}
