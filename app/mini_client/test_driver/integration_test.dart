import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Host side of `flutter drive`: writes each in-test screenshot to
/// `$SCREENSHOT_DIR` (set by `tool/e2e_ios.sh`). It fails when the variable
/// is missing, so a run can never pass without producing evidence.
Future<void> main() async {
  final outDir = Platform.environment['SCREENSHOT_DIR'];
  if (outDir == null || outDir.isEmpty) {
    stderr.writeln('SCREENSHOT_DIR is not set; run through tool/e2e_ios.sh');
    exit(2);
  }
  await integrationDriver(
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          final file = File('$outDir/$name.png');
          await file.create(recursive: true);
          await file.writeAsBytes(bytes);
          stdout.writeln('SCREENSHOT_WRITTEN ${file.path} (${bytes.length})');
          return true;
        },
  );
}
