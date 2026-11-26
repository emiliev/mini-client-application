import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// How long the typist waits between two keystrokes: well inside any
/// debounce the app uses (300 ms for search).
const Duration mcKeystrokeInterval = Duration(milliseconds: 100);

/// Usage: I type {'spi'} one character at a time
///
/// Types [text] into the one text field on screen a character at a time
/// ("s", "sp", "spi"), [mcKeystrokeInterval] of fake time apart, so every
/// keystroke lands inside a debounce window. It does **not** settle: the
/// step ends right after the last keystroke, so the next step decides how
/// much time passes (`{300} milliseconds pass`).
Future<void> iTypeOneCharacterAtATime(WidgetTester tester, String text) async {
  final field = find.byType(EditableText);
  expect(field, findsOneWidget, reason: 'exactly one text field');
  final characters = text.runes.toList();
  for (var i = 1; i <= characters.length; i++) {
    if (i > 1) {
      await tester.pump(mcKeystrokeInterval);
    }
    await tester.enterText(
      field,
      String.fromCharCodes(characters.take(i)),
    );
  }
  await tester.pump();
}
