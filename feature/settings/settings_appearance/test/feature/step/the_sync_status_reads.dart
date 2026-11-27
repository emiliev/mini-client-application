import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/settings_appearance_env.dart';

/// Usage: the sync status reads {'Saved on this device.'}
///
/// The sync status line says exactly this.
Future<void> theSyncStatusReads(WidgetTester tester, String text) async {
  await tester.pump();
  final status = find.byKey(syncStatusKey);
  await scrollSettingsTo(tester, status);
  expect(tester.widget<Text>(status).data, text);
}
