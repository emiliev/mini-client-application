import 'package:mc_formatters/mc_formatters.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(initializeFormatters);

  test('T-0025-AC2 Money(1999, EUR) formats as 19,99 € in de', () {
    // intl separates the amount and the symbol with U+00A0.
    expect(formatMoney(const Money(1999, Currency.eur), 'de'), '19,99 €');
  });

  test('T-0025-AC2 Money(1999, EUR) formats as €19.99 in en', () {
    expect(formatMoney(const Money(1999, Currency.eur), 'en'), '€19.99');
  });

  test('T-0025-AC2 zero-decimal currencies keep the minor unit', () {
    expect(formatMoney(const Money(500, Currency.jpy), 'en'), '¥500');
  });

  test('T-0025-AC2 dates and compact numbers are locale-aware', () {
    final date = DateTime(2026, 11, 24);
    expect(formatDate(date, 'en'), 'Nov 24, 2026');
    expect(formatDate(date, 'de'), '24. Nov. 2026');
    expect(formatCompact(1200, 'en'), '1.2K');
    expect(formatNumber(1234567.5, 'de'), '1.234.567,5');
  });
}
