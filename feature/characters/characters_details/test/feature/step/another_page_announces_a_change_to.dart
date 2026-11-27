import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_event_bus/mc_event_bus.dart';

/// Usage: another page announces a change to {'favourites'}
///
/// Something else in the app (another page of the same character, another
/// feature) publishes `DataChanged(topic)` on the app's bus, as a favourite
/// write elsewhere does. Frames are pumped so a read it causes has started.
Future<void> anotherPageAnnouncesAChangeTo(
  WidgetTester tester,
  String topic,
) async {
  diContainer<EventBus>().publish(DataChanged(topic));
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
