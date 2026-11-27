import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I leave the store
///
/// The flow is removed from the tree, so its pages and blocs are disposed
/// (the user left the store).
Future<void> iLeaveTheStore(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
}
