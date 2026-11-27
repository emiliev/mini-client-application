import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_forms/mc_ds_forms.dart';

/// Usage: the submit button reads {'Try again'}
///
/// The form's one submit button shows [label].
Future<void> theSubmitButtonReads(WidgetTester tester, String label) async =>
    expect(
      find.descendant(
        of: find.byKey(McFormScaffold.submitKey),
        matching: find.text(label),
      ),
      findsOneWidget,
      reason: 'the submit button reads "$label"',
    );
