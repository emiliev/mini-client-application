import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

Future<McL10nCoreL10n> _load(WidgetTester tester, Locale locale) async {
  late McL10nCoreL10n l10n;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: mcSupportedLocales(includePseudo: true),
      localizationsDelegates: mcLocalizationsDelegates,
      home: Builder(
        builder: (context) {
          l10n = McL10nCoreL10n.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return l10n;
}

void main() {
  testWidgets('T-0025-AC1 de resolves the common strings in German', (
    tester,
  ) async {
    final l10n = await _load(tester, const Locale('de'));
    expect(l10n.commonCancel, 'Abbrechen');
    expect(l10n.commonRetry, 'Erneut versuchen');
    expect(l10n.errorGeneric, 'Etwas ist schiefgelaufen.');
  });

  testWidgets('T-0025-AC1 en resolves the English strings', (tester) async {
    final l10n = await _load(tester, const Locale('en'));
    expect(l10n.commonCancel, 'Cancel');
    expect(l10n.commonOk, 'OK');
  });

  testWidgets('T-0025-AC1 en_XA renders the pseudo-localised strings', (
    tester,
  ) async {
    final l10n = await _load(tester, mcPseudoLocale);
    expect(l10n.commonRetry, '[Ŕéţŕý ~~]');
    expect(l10n.commonCancel, startsWith('['));
  });

  test('T-0025-AC1 release locales exclude the pseudo-locale (R24)', () {
    expect(mcSupportedLocales(), isNot(contains(mcPseudoLocale)));
    expect(mcSupportedLocales(includePseudo: true), contains(mcPseudoLocale));
  });
}
