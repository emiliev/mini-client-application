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

  test('T-0025-AC2 date-time follows the locale clock (en 12 h, de 24 h)', () {
    final date = DateTime(2026, 11, 24, 15, 30);
    final en = formatDateTime(date, 'en');
    final de = formatDateTime(date, 'de');
    expect(en, startsWith('11/24/2026'));
    expect(en, contains('3:30'));
    expect(en, contains('PM'));
    expect(de, '24.11.2026 15:30');
  });

  test('T-0025-AC2 dates and compact numbers are locale-aware', () {
    final date = DateTime(2026, 11, 24);
    expect(formatDate(date, 'en'), 'Nov 24, 2026');
    expect(formatDate(date, 'de'), '24. Nov. 2026');
    expect(formatCompact(1200, 'en'), '1.2K');
    expect(formatNumber(1234567.5, 'de'), '1.234.567,5');
  });

  test('T-0041-AC8 Money is a value: equal by amount and currency', () {
    const a = Money(399, Currency.usd);
    expect(a, const Money(399, Currency.usd));
    expect(a.hashCode, const Money(399, Currency.usd).hashCode);
    expect(a, isNot(const Money(399, Currency.eur)));
    expect(a, isNot(const Money(400, Currency.usd)));
    expect('$a', 'Money(399, USD)');
  });
}
