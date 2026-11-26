import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the field reads {'spi'}
///
/// The one text field on screen holds exactly [text] (`''` for empty).
Future<void> theFieldReads(WidgetTester tester, String text) async {
  final field = find.byType(EditableText);
  expect(field, findsOneWidget, reason: 'exactly one text field');
  expect(tester.widget<EditableText>(field).controller.text, text);
}
