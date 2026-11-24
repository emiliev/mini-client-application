import 'package:flutter_test/flutter_test.dart';

/// Usage: I see {'Hero 01'}
Future<void> iSee(WidgetTester tester, String text) async =>
    expect(find.text(text), findsWidgets, reason: 'expected to see "$text"');
