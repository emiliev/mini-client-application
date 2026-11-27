import 'package:mc_fixtures_commerce/src/data/catalogue.dart';

/// The most units of one product a cart line may hold.
const int maxQuantity = 99;

enum PromotionKind {
  percentOff('percent_off'),
  fixedOff('fixed_off'),
  buyTwoGetOne('buy_2_get_1');

  const PromotionKind(this.wireName);

  final String wireName;
}

/// A promotion code. At most one of each kind can be on a cart.
final class Promotion {
  const Promotion.percent(this.code, this.title, int percent)
    : kind = PromotionKind.percentOff,
      percent = percent,
      amountCents = 0,
      minSubtotalCents = 0,
      categoryId = null;

  const Promotion.fixed(
    this.code,
    this.title,
    this.amountCents,
    this.minSubtotalCents,
  ) : kind = PromotionKind.fixedOff,
      percent = 0,
      categoryId = null;

  const Promotion.buyTwoGetOne(this.code, this.title, String category)
    : kind = PromotionKind.buyTwoGetOne,
      categoryId = category,
      percent = 0,
      amountCents = 0,
      minSubtotalCents = 0;

  final String code;
  final String title;
  final PromotionKind kind;
  final int percent;
  final int amountCents;

  /// Fixed-off only: the subtotal (after the two steps before it) at which it
  /// takes effect.
  final int minSubtotalCents;

  /// Buy-2-get-1 only.
  final String? categoryId;
}

const List<Promotion> promotions = [
  Promotion.percent('SAVE10', '10% off your order', 10),
  Promotion.percent('SAVE25', '25% off your order', 25),
  Promotion.fixed('TAKE5', '5.00 EUR off orders from 25.00 EUR', 500, 2500),
  Promotion.fixed('TAKE15', '15.00 EUR off orders from 80.00 EUR', 1500, 8000),
  Promotion.buyTwoGetOne('HEROES3', 'Buy 2 get 1 on Heroes', 'heroes'),
  Promotion.buyTwoGetOne('COSMIC3', 'Buy 2 get 1 on Cosmic', 'cosmic'),
];

/// The promotion of [raw] (trimmed, case-insensitive), or null.
Promotion? promotionFor(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final wanted = raw.trim().toUpperCase();
  for (final p in promotions) {
    if (p.code == wanted) {
      return p;
    }
  }
  return null;
}

/// One cart line as the pricing sees it.
final class LineInput {
  const LineInput({
    required this.productId,
    required this.title,
    required this.categoryId,
    required this.listCents,
    required this.unitCents,
    required this.quantity,
  });

  final int productId;
  final String title;
  final String categoryId;

  /// The list price of one unit, and what the cart charges (the deal price
  /// when the product has a deal).
  final int listCents;
  final int unitCents;
  final int quantity;
}

/// One priced line. All amounts are integer cents.
final class PricedLine {
  PricedLine(this.input) : subtotalCents = input.unitCents * input.quantity;

  final LineInput input;

  /// Unit price times quantity.
  final int subtotalCents;

  /// The discount of each step on this line (stacking order, CONTRACT.md).
  int buyTwoGetOneCents = 0;
  int percentCents = 0;
  int fixedCents = 0;

  int get discountCents => buyTwoGetOneCents + percentCents + fixedCents;
  int get totalCents => subtotalCents - discountCents;
}

/// What one promotion on the cart is worth.
final class PromotionResult {
  const PromotionResult(this.promotion, this.discountCents, this.eligible);

  final Promotion promotion;
  final int discountCents;

  /// False when the cart no longer meets the promotion's condition (it then
  /// takes nothing off).
  final bool eligible;
}

final class PricedCart {
  PricedCart(this.lines, this.promotions, this.beforeFixedCents);

  final List<PricedLine> lines;
  final List<PromotionResult> promotions;

  /// The subtotal after steps 1 to 3: what a fixed-off minimum is checked
  /// against.
  final int beforeFixedCents;

  int get subtotalCents => lines.fold(0, (a, l) => a + l.subtotalCents);
  int get discountCents => lines.fold(0, (a, l) => a + l.discountCents);
  int get totalCents => lines.fold(0, (a, l) => a + l.totalCents);
  int get itemCount => lines.fold(0, (a, l) => a + l.input.quantity);
}

/// Prices a cart. The stacking order is fixed, whatever the order the codes
/// were applied in:
///
///  1. line subtotal = unit price (deal price if any) x quantity;
///  2. buy-2-get-1 on its category;
///  3. percent-off on what is left of each line, rounded half-up per line;
///  4. fixed-off, if the subtotal after 2 and 3 reaches its minimum, shared
///     over the lines in proportion to what is left of each.
PricedCart priceCart(List<LineInput> inputs, List<Promotion> applied) {
  final lines = [for (final i in inputs) PricedLine(i)];
  final results = <Promotion, PromotionResult>{};

  for (final p in applied.where((p) => p.kind == PromotionKind.buyTwoGetOne)) {
    // Every unit of the category, dearest first (ties by line order); the
    // third unit of each group of three is free, so the cheapest of the
    // group.
    final units = <(int price, int line)>[];
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].input.categoryId == p.categoryId) {
        for (var q = 0; q < lines[i].input.quantity; q++) {
          units.add((lines[i].input.unitCents, i));
        }
      }
    }
    units.sort(
      (a, b) => a.$1 != b.$1 ? b.$1.compareTo(a.$1) : a.$2.compareTo(b.$2),
    );
    var taken = 0;
    for (var n = 2; n < units.length; n += 3) {
      lines[units[n].$2].buyTwoGetOneCents += units[n].$1;
      taken += units[n].$1;
    }
    results[p] = PromotionResult(p, taken, units.length >= 3);
  }

  for (final p in applied.where((p) => p.kind == PromotionKind.percentOff)) {
    var taken = 0;
    for (final line in lines) {
      final cut = percentOfHalfUp(
        line.subtotalCents - line.buyTwoGetOneCents,
        p.percent,
      );
      line.percentCents += cut;
      taken += cut;
    }
    results[p] = PromotionResult(p, taken, lines.isNotEmpty);
  }

  final remaining = [
    for (final l in lines)
      l.subtotalCents - l.buyTwoGetOneCents - l.percentCents,
  ];
  final beforeFixed = remaining.fold(0, (a, b) => a + b);

  for (final p in applied.where((p) => p.kind == PromotionKind.fixedOff)) {
    final eligible = beforeFixed > 0 && beforeFixed >= p.minSubtotalCents;
    var taken = 0;
    if (eligible) {
      // Every shipped minimum is above its amount, so the amount is always
      // covered by what is left.
      taken = p.amountCents;
      // Proportional shares, rounded down; the cents left over go one each to
      // the lines with the largest remainders (ties: the earlier line).
      final shares = [
        for (final r in remaining) taken * r ~/ beforeFixed,
      ];
      final remainders = [
        for (final r in remaining) taken * r % beforeFixed,
      ];
      var left = taken - shares.fold(0, (a, b) => a + b);
      final order = [for (var i = 0; i < lines.length; i++) i]
        ..sort(
          (a, b) => remainders[a] != remainders[b]
              ? remainders[b].compareTo(remainders[a])
              : a.compareTo(b),
        );
      for (final i in order) {
        if (left == 0) {
          break;
        }
        shares[i] += 1;
        left -= 1;
      }
      for (var i = 0; i < lines.length; i++) {
        lines[i].fixedCents += shares[i];
      }
    }
    results[p] = PromotionResult(p, taken, eligible);
  }

  return PricedCart(lines, [
    for (final p in applied) results[p]!,
  ], beforeFixed);
}
