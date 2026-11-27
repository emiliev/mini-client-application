import 'support.dart';

/// An independent model of the cart arithmetic (T-0051-AC3), written from
/// CONTRACT.md, "Cart arithmetic". It shares no code with the package: the
/// promotion table is repeated here as literals, and each rule is computed a
/// different way than the production code (digit by digit rounding, a unit
/// ledger instead of a sort, remainders as a fraction list).
final class OracleResult {
  OracleResult(this.lineTotals, this.lineDiscounts, this.byCode);

  final List<int> lineTotals;
  final List<int> lineDiscounts;

  /// Cents taken off by each code.
  final Map<String, int> byCode;

  int get total => lineTotals.fold(0, (a, b) => a + b);
}

const Map<String, int> _percentCodes = {'SAVE10': 10, 'SAVE25': 25};
const Map<String, (int amount, int minimum)> _fixedCodes = {
  'TAKE5': (500, 2500),
  'TAKE15': (1500, 8000),
};
const Map<String, String> _freeThirdCodes = {
  'HEROES3': 'heroes',
  'COSMIC3': 'cosmic',
};

/// [lines] are the cart's lines in the order the cart lists them.
OracleResult oracleCart(
  List<(ProductView product, int quantity)> lines,
  List<String> codes,
) {
  final n = lines.length;
  final base = [for (final (p, q) in lines) p.unitCents * q];
  final discount = List<int>.filled(n, 0);
  final byCode = <String, int>{};

  // Buy 2 get 1: a ledger of single units of the category. Walk it from the
  // dearest unit down (equal prices: earlier line first); every third unit
  // walked is free.
  for (final code in codes.where(_freeThirdCodes.containsKey)) {
    final category = _freeThirdCodes[code];
    final ledger = <({int price, int line})>[];
    for (var i = 0; i < n; i++) {
      if (lines[i].$1.category != category) {
        continue;
      }
      for (var k = 0; k < lines[i].$2; k++) {
        ledger.add((price: lines[i].$1.unitCents, line: i));
      }
    }
    ledger.sort((x, y) {
      if (x.price != y.price) {
        return y.price - x.price;
      }
      return x.line - y.line;
    });
    var walked = 0;
    var taken = 0;
    for (final unit in ledger) {
      walked++;
      if (walked % 3 == 0) {
        discount[unit.line] += unit.price;
        taken += unit.price;
      }
    }
    byCode[code] = taken;
  }

  // Percent: half-up per line, from the quotient and remainder by 100.
  for (final code in codes.where(_percentCodes.containsKey)) {
    final percent = _percentCodes[code]!;
    var taken = 0;
    for (var i = 0; i < n; i++) {
      final left = base[i] - discount[i];
      final product = left * percent;
      var cut = product ~/ 100;
      if (product % 100 >= 50) {
        cut += 1;
      }
      discount[i] += cut;
      taken += cut;
    }
    byCode[code] = taken;
  }

  // Fixed: against what is left after the two steps above.
  final left = [for (var i = 0; i < n; i++) base[i] - discount[i]];
  final leftTotal = left.fold(0, (a, b) => a + b);
  for (final code in codes.where(_fixedCodes.containsKey)) {
    final (amount, minimum) = _fixedCodes[code]!;
    if (leftTotal == 0 || leftTotal < minimum) {
      byCode[code] = 0;
      continue;
    }
    final cut = amount > leftTotal ? leftTotal : amount;
    // Each line's exact share is cut * left / leftTotal: whole cents first,
    // then the remaining cents to the largest fractions (ties: first line).
    final whole = [for (final l in left) cut * l ~/ leftTotal];
    final fraction = [for (final l in left) cut * l % leftTotal];
    var spare = cut - whole.fold(0, (a, b) => a + b);
    while (spare > 0) {
      var best = -1;
      for (var i = 0; i < n; i++) {
        if (fraction[i] < 0) {
          continue;
        }
        if (best == -1 || fraction[i] > fraction[best]) {
          best = i;
        }
      }
      whole[best] += 1;
      fraction[best] = -1;
      spare -= 1;
    }
    for (var i = 0; i < n; i++) {
      discount[i] += whole[i];
    }
    byCode[code] = cut;
  }

  return OracleResult(
    [for (var i = 0; i < n; i++) base[i] - discount[i]],
    discount,
    byCode,
  );
}
