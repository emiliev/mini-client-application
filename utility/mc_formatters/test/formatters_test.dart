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

  test('T-0056-AC1 integer cents format as euros in en: 1299 is €12.99', () {
    expect(formatMoney(const Money(1299, Currency.eur), 'en'), '€12.99');
    expect(formatMoney(const Money(5, Currency.eur), 'en'), '€0.05');
    expect(formatMoney(const Money(0, Currency.eur), 'en'), '€0.00');
    expect(formatMoney(const Money(100, Currency.eur), 'en'), '€1.00');
    expect(
      formatMoney(const Money(123456789, Currency.eur), 'en'),
      '€1,234,567.89',
    );
  });

  test('T-0056-AC4 integer cents format as euros in de: 1299 is 12,99 €', () {
    // intl separates the amount and the symbol with U+00A0.
    expect(formatMoney(const Money(1299, Currency.eur), 'de'), '12,99\u00a0€');
    expect(formatMoney(const Money(5, Currency.eur), 'de'), '0,05\u00a0€');
    expect(
      formatMoney(const Money(123456789, Currency.eur), 'de'),
      '1.234.567,89\u00a0€',
    );
  });

  test('T-0056-AC1 every cent amount formats exactly (no binary rounding)', () {
    // Each of the 10,000 cent values below 100 euros, and a large one near
    // the top of the store's range, comes out digit for digit.
    for (var cents = 0; cents < 10000; cents++) {
      final euros = cents ~/ 100;
      final rest = (cents % 100).toString().padLeft(2, '0');
      expect(
        formatMoney(Money(cents, Currency.eur), 'en'),
        '€$euros.$rest',
        reason: '$cents cents',
      );
    }
    expect(
      formatMoney(const Money(99999999999, Currency.eur), 'en'),
      '€999,999,999.99',
    );
  });

  test('T-0056-AC1 Currency.parse reads ISO codes and refuses others', () {
    expect(Currency.parse('EUR'), Currency.eur);
    expect(Currency.parse('USD'), Currency.usd);
    expect(Currency.parse('JPY'), Currency.jpy);
    expect(() => Currency.parse('eur'), throwsFormatException);
    expect(() => Currency.parse('XXX'), throwsFormatException);
    expect(() => Currency.parse(''), throwsFormatException);
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
