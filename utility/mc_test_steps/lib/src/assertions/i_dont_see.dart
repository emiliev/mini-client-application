import 'package:flutter_test/flutter_test.dart';

/// Usage: I don't see {'Hero 01'}
Future<void> iDontSee(WidgetTester tester, String text) async =>
    expect(find.text(text), findsNothing, reason: 'expected no "$text"');
