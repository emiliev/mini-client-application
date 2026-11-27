import 'dart:async';

import 'package:mc_fixtures_commerce/src/data/catalogue.dart';
import 'package:mc_fixtures_commerce/src/data/pricing.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

const String _cartsKey = 'commerce.carts';
const String _emptyCartsKey = 'commerce.carts.empty';

/// One user's cart: lines in the order they were added, and the codes applied.
final class Cart {
  /// Product id -> quantity, in insertion order.
  final Map<int, int> quantities = {};
  final List<Promotion> promotions = [];
}

/// Every user's cart, kept in the backend's store until `reset()`. The empty
/// store keeps its own, so switching `commerce.empty` never leaves a line
/// that names a product the other catalogue lacks.
Cart _cartOf(MockContext context, String userId, {required bool empty}) {
  final key = empty ? _emptyCartsKey : _cartsKey;
  final carts = (context.store[key] ??= <String, Cart>{}) as Map<String, Cart>;
  return carts.putIfAbsent(userId, Cart.new);
}

MockResponse _unauthenticated() => MockResponse.error(
  401,
  'unauthenticated',
  'A valid bearer token is required',
);

MockResponse _unknownProduct(String raw) => MockResponse.error(
  404,
  'unknown_product',
  'No product "$raw"',
  extra: {'productId': raw},
);

MockResponse _invalidQuantity() => MockResponse.error(
  400,
  'invalid_quantity',
  'quantity must be a whole number from 0 to $maxQuantity',
  extra: {'parameter': 'quantity', 'min': 0, 'max': maxQuantity},
);

MockResponse _unknownPromo(Object? code) => MockResponse.error(
  404,
  'unknown_promo',
  'No promotion code "$code"',
  extra: {'promoCode': '$code'},
);

MockResponse _notApplicable(Promotion promo, String reason) =>
    MockResponse.error(
      409,
      'promo_not_applicable',
      '${promo.code} cannot be applied: $reason',
      extra: {'promoCode': promo.code, 'reason': reason},
    );

final MockResponse _notAnObject = MockResponse.error(
  400,
  'invalid_body',
  'Expected a JSON object',
  extra: {'parameter': 'body'},
);

/// Wraps [body] with the bearer check; [body] gets the signed-in user.
MockHandler _authed(
  FutureOr<MockResponse> Function(
    FixtureUser user,
    MockRequest request,
    MockContext context,
  )
  body,
) => (request, context) {
  final user = userForAuthorization(request.headers['authorization']);
  return user == null ? _unauthenticated() : body(user, request, context);
};

PricedCart _price(Cart cart, Catalogue catalogue) => priceCart([
  for (final MapEntry(:key, :value) in cart.quantities.entries)
    LineInput(
      productId: key,
      title: catalogue.byId[key]!.title,
      categoryId: catalogue.byId[key]!.categoryId,
      listCents: catalogue.byId[key]!.priceCents,
      unitCents: catalogue.byId[key]!.unitPriceCents,
      quantity: value,
    ),
], cart.promotions);

Map<String, Object?> _cartJson(Cart cart, Catalogue catalogue) {
  final priced = _price(cart, catalogue);
  return {
    'currency': currencyCode,
    'items': [
      for (final line in priced.lines)
        {
          'productId': line.input.productId,
          'title': line.input.title,
          'cover': catalogue.byId[line.input.productId]!.cover.toJson(),
          'quantity': line.input.quantity,
          'listPriceCents': line.input.listCents,
          'unitPriceCents': line.input.unitCents,
          'subtotalCents': line.subtotalCents,
          'discountCents': line.discountCents,
          'totalCents': line.totalCents,
        },
    ],
    'itemCount': priced.itemCount,
    'promotions': [
      for (final r in priced.promotions)
        {
          'code': r.promotion.code,
          'kind': r.promotion.kind.wireName,
          'title': r.promotion.title,
          'eligible': r.eligible,
          'discountCents': r.discountCents,
        },
    ],
    'subtotalCents': priced.subtotalCents,
    'discountCents': priced.discountCents,
    'totalCents': priced.totalCents,
  };
}

/// `GET /v1/me/cart`.
MockHandler getCart({required bool empty}) => _authed((user, request, context) {
  final catalogue = catalogueFor(context.seed, empty: empty);
  return MockResponse.ok(
    _cartJson(_cartOf(context, user.id, empty: empty), catalogue),
  );
});

/// `PUT /v1/me/cart/items/:productId` with `{quantity}`; 0 removes the line.
/// Checks, in order: auth, product, body, quantity range, stock.
MockHandler putItem({required bool empty}) => _authed((
  user,
  request,
  context,
) {
  final catalogue = catalogueFor(context.seed, empty: empty);
  final raw = context.params['productId']!;
  final productId = RegExp(r'^\d+$').hasMatch(raw) ? int.parse(raw) : null;
  final product = productId == null ? null : catalogue.byId[productId];
  if (product == null) {
    return _unknownProduct(raw);
  }
  final body = request.body;
  if (body is! Map) {
    return _notAnObject;
  }
  final quantity = body['quantity'];
  if (quantity is! int || quantity < 0 || quantity > maxQuantity) {
    return _invalidQuantity();
  }
  if (quantity > product.stock) {
    return MockResponse.error(
      409,
      'out_of_stock',
      'Only ${product.stock} of "${product.title}" in stock',
      extra: {
        'productId': product.id,
        'requested': quantity,
        'available': product.stock,
      },
    );
  }
  final cart = _cartOf(context, user.id, empty: empty);
  if (quantity == 0) {
    cart.quantities.remove(product.id);
    if (cart.quantities.isEmpty) {
      // An empty cart carries no codes.
      cart.promotions.clear();
    }
  } else {
    cart.quantities[product.id] = quantity;
  }
  return MockResponse.ok(_cartJson(cart, catalogue));
});

/// `POST /v1/me/cart/promo` with `{code}`.
MockHandler applyPromo({required bool empty}) => _authed((
  user,
  request,
  context,
) {
  final catalogue = catalogueFor(context.seed, empty: empty);
  final body = request.body;
  if (body is! Map) {
    return _notAnObject;
  }
  if (body['code'] is! String) {
    return MockResponse.error(
      400,
      'invalid_body',
      'code must be a string',
      extra: {'parameter': 'code'},
    );
  }
  final promo = promotionFor(body['code']);
  if (promo == null) {
    return _unknownPromo(body['code']);
  }
  final cart = _cartOf(context, user.id, empty: empty);
  if (cart.promotions.contains(promo)) {
    return _notApplicable(promo, 'already_applied');
  }
  if (cart.promotions.any((p) => p.kind == promo.kind)) {
    return _notApplicable(promo, 'kind_already_applied');
  }
  if (cart.quantities.isEmpty) {
    return _notApplicable(promo, 'empty_cart');
  }
  if (promo.kind == PromotionKind.buyTwoGetOne &&
      !cart.quantities.keys.any(
        (id) => catalogue.byId[id]!.categoryId == promo.categoryId,
      )) {
    return _notApplicable(promo, 'no_matching_items');
  }
  if (promo.kind == PromotionKind.fixedOff &&
      _price(cart, catalogue).beforeFixedCents < promo.minSubtotalCents) {
    return _notApplicable(promo, 'minimum_not_met');
  }
  cart.promotions.add(promo);
  return MockResponse.ok(_cartJson(cart, catalogue));
});

/// `DELETE /v1/me/cart/promo`: every code, or just `?code=`.
MockHandler removePromo({required bool empty}) => _authed((
  user,
  request,
  context,
) {
  final catalogue = catalogueFor(context.seed, empty: empty);
  final cart = _cartOf(context, user.id, empty: empty);
  final raw = request.query['code'];
  if (raw == null) {
    cart.promotions.clear();
  } else {
    final promo = promotionFor(raw);
    if (promo == null) {
      return _unknownPromo(raw);
    }
    if (!cart.promotions.remove(promo)) {
      return _notApplicable(promo, 'not_applied');
    }
  }
  return MockResponse.ok(_cartJson(cart, catalogue));
});
