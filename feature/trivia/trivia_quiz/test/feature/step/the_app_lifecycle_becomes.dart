import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const List<AppLifecycleState> _order = [
  AppLifecycleState.resumed,
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];

/// Usage: the app lifecycle becomes {'paused'}
///
/// Walks the app's lifecycle to [state] one legal step at a time, as iOS
/// does (resumed, inactive, hidden, paused, and back), then draws a frame.
/// The tear-down brings it back to resumed for the next test.
Future<void> theAppLifecycleBecomes(WidgetTester tester, String state) async {
  final target = AppLifecycleState.values.byName(state);
  final binding = tester.binding;
  var now = _order.indexOf(binding.lifecycleState ?? AppLifecycleState.resumed);
  final to = _order.indexOf(target);
  while (now != to) {
    now += now < to ? 1 : -1;
    binding.handleAppLifecycleStateChanged(_order[now]);
  }
  addTearDown(() {
    var i = _order.indexOf(binding.lifecycleState ?? AppLifecycleState.resumed);
    while (i > 0) {
      i--;
      binding.handleAppLifecycleStateChanged(_order[i]);
    }
  });
  await tester.pump();
}
