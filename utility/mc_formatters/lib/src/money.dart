/// Currencies the app displays, with their ISO 4217 minor-unit digits.
enum Currency {
  eur('EUR', 2),
  usd('USD', 2),
  gbp('GBP', 2),
  jpy('JPY', 0);

  const Currency(this.code, this.fractionDigits);

  /// ISO 4217 code.
  final String code;

  /// Digits after the decimal separator (`minorUnits` = amount * 10^digits).
  final int fractionDigits;
}

/// An amount in minor units (cents), so no floating point is involved.
///
/// `Money(1999, Currency.eur)` is 19.99 EUR.
class Money {
  const Money(this.minorUnits, this.currency);

  final int minorUnits;
  final Currency currency;

  /// The amount in major units, for display formatting only.
  num get majorUnits {
    var divisor = 1;
    for (var i = 0; i < currency.fractionDigits; i++) {
      divisor *= 10;
    }
    return minorUnits / divisor;
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => 'Money($minorUnits, ${currency.code})';
}
