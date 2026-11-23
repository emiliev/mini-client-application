import 'dart:io';

import 'package:mc_config/mc_config.dart';
import 'package:test/test.dart';

void main() {
  test('T-0020-AC1 bundled app_config.json matches the selected env', () {
    final path = Platform.environment['MC_CONFIG_JSON'];
    final expected = Platform.environment['MC_EXPECT_ENV'];
    if (path == null || expected == null) {
      markTestSkipped('Needs the Bazel-bundled config; run via tool/bazelw.');
      return;
    }
    final config = AppConfig.parse(File(path).readAsStringSync());
    expect(config.env, expected);
    if (expected == 'dev') {
      expect(config.backend.latency, const Duration(milliseconds: 250));
    } else {
      expect(config.backend.latency, Duration.zero);
    }
  });
}
