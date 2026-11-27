import 'package:flutter_test/flutter_test.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the device keeps {'dark'} {'compact'} with reduce motion {'on'}
///
/// The device's saved copy (`mc_storage`, read here synchronously as a new
/// launch would) holds these values: the choice survives a restart.
Future<void> theDeviceKeepsWithReduceMotion(
  WidgetTester tester,
  String themeMode,
  String density,
  String onOrOff,
) async {
  final saved = FileStore(
    McTestSession.current.storageDirectory,
  ).readSync(appearanceStoreKey).getOrNull();
  expect(saved, isA<Map<String, Object?>>(), reason: 'a saved appearance');
  final map = saved! as Map<String, Object?>;
  expect(map['themeMode'], themeMode);
  expect(map['density'], density);
  expect(map['reduceMotion'], onOrOff == 'on');
}
