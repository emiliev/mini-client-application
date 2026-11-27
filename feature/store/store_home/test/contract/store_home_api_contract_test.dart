// Contract tests are the one place a feature test reaches `src/` (R7): the
// DTOs and the mapper against what `mc_fixtures_commerce` serves.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_commerce/mc_fixtures_commerce.dart'
    show Catalogue, CommerceMockDomain, catalogueFor;
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_formatters/mc_formatters.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:store_home/src/domain/model/category_id.dart';
import 'package:store_home/src/domain/model/comic_id.dart';
import 'package:store_home/src/domain/model/store.dart';
import 'package:store_home/src/domain/model/store_dto.dart';
import 'package:store_home/src/domain/model/store_mapper.dart';

final Dio _dio = MockBackend(
  domains: [const CommerceMockDomain(), const IdentityMockDomain()],
).createDio();

Future<Map<String, dynamic>> _get(String path, {String? bearer}) async =>
    (await _dio.get<Map<String, dynamic>>(
      path,
      options: Options(
        headers: {if (bearer != null) 'Authorization': 'Bearer $bearer'},
      ),
    )).data!;

/// Encodes JSON with sorted keys, as the backend does, so equal data is
/// equal text.
String _canonical(Object? json) => jsonEncode(_sorted(json));

Object? _sorted(Object? json) => switch (json) {
  final Map<String, dynamic> map => {
    for (final key in map.keys.toList()..sort()) key: _sorted(map[key]),
  },
  final List<dynamic> list => [for (final e in list) _sorted(e)],
  _ => json,
};

final Catalogue _catalogue = catalogueFor(42, empty: false);

void main() {
  group('T-0056-AC8 every store route round-trips through its DTO', () {
    test('T-0056-AC8 banners', () async {
      final body = await _get('v1/store/banners');
      expect(
        _canonical(BannersDto.fromJson(body).toJson()),
        _canonical(body),
      );
    });

    test('T-0056-AC8 deals', () async {
      final body = await _get('v1/store/deals');
      expect(_canonical(DealsDto.fromJson(body).toJson()), _canonical(body));
    });

    test('T-0056-AC8 categories', () async {
      final body = await _get('v1/store/categories');
      expect(
        _canonical(CategoriesDto.fromJson(body).toJson()),
        _canonical(body),
      );
    });

    test('T-0056-AC8 featured', () async {
      final body = await _get('v1/store/featured');
      expect(
        _canonical(FeaturedDto.fromJson(body).toJson()),
        _canonical(body),
      );
    });

    test('T-0056-AC8 a category page: every product round-trips', () async {
      final body = await _get('v1/store/categories/heroes/products');
      final results = body['results'] as List<dynamic>;
      expect(results, hasLength(20));
      for (final product in results) {
        final json = product as Map<String, dynamic>;
        expect(
          _canonical(ProductDto.fromJson(json).toJson()),
          _canonical(json),
        );
      }
    });

    test('T-0056-AC8 the cart: the summary fields the store reads', () async {
      final body = await _get(
        'v1/me/cart',
        bearer: mintAccessToken(fixtureUsers.first.id, 1),
      );
      final dto = CartSummaryDto.fromJson(body);
      expect(dto.currency, 'EUR');
      expect(dto.itemCount, body['itemCount']);
      expect(dto.totalCents, body['totalCents']);
      expect(body['totalCents'], isA<int>(), reason: 'money is integer cents');
    });
  });

  group('T-0056-AC1 the mapper keeps money in integer cents', () {
    test(
      'T-0056-AC1 a deal maps both prices, the percent and the end',
      () async {
        final body = await _get('v1/store/deals');
        final deals = [
          for (final d in body['deals'] as List<dynamic>)
            DealDto.fromJson(d as Map<String, dynamic>).toDomain(),
        ];
        expect(deals, hasLength(_catalogue.deals.length));
        for (var i = 0; i < deals.length; i++) {
          final product = _catalogue.deals[i];
          final deal = deals[i];
          expect(deal.product.id, ComicId(product.id));
          expect(deal.product.title, product.title);
          expect(deal.originalPrice, Money(product.priceCents, Currency.eur));
          expect(
            deal.dealPrice,
            Money(product.deal!.dealPriceCents, Currency.eur),
          );
          expect(deal.product.dealPrice, deal.dealPrice);
          expect(deal.discountPercent, product.deal!.discountPercent);
          expect(
            deal.endsAt,
            defaultMockClock.add(Duration(days: product.deal!.endsInDays)),
          );
          expect(deal.endsAt.isUtc, isTrue);
        }
      },
    );

    test('T-0056-AC1 a product without a deal has no deal price', () async {
      final body = await _get('v1/store/featured');
      final first = ProductDto.fromJson(
        (body['products'] as List<dynamic>).first as Map<String, dynamic>,
      ).toDomain();
      final product = _catalogue.featured.first;
      expect(first.price, Money(product.priceCents, Currency.eur));
      expect(first.dealPrice, isNull);
      expect(first.cover.variant, ImageVariant.portraitLarge);
    });

    test('T-0056-AC1 the cart summary maps count and total', () {
      final cart = const CartSummaryDto(
        currency: 'EUR',
        itemCount: 3,
        totalCents: 4329,
      ).toDomain();
      expect(cart.itemCount, 3);
      expect(cart.total, const Money(4329, Currency.eur));
    });

    test('T-0056-AC1 days left round up, and an ended deal has none', () {
      Deal endingAt(DateTime end) => Deal(
        product: const Product(
          id: ComicId(1),
          title: 't',
          cover: ApiImage(path: 'p', variant: ImageVariant.standard),
          price: Money(100, Currency.eur),
        ),
        originalPrice: const Money(100, Currency.eur),
        dealPrice: const Money(90, Currency.eur),
        discountPercent: 10,
        endsAt: end,
      );
      final now = defaultMockClock;
      expect(endingAt(now.add(const Duration(days: 1))).daysLeftAt(now), 1);
      expect(endingAt(now.add(const Duration(hours: 25))).daysLeftAt(now), 2);
      expect(
        endingAt(now.add(const Duration(microseconds: 1))).daysLeftAt(now),
        1,
      );
      expect(endingAt(now).daysLeftAt(now), 0);
      expect(
        endingAt(now.subtract(const Duration(days: 1))).daysLeftAt(now),
        0,
      );
      expect(endingAt(now.add(const Duration(days: 8))).daysLeftAt(now), 8);
    });
  });

  group('T-0056-AC3 banner targets', () {
    test('T-0056-AC3 the served banners map to a comic, a category and a '
        'search', () async {
      final body = await _get('v1/store/banners');
      final targets = [
        for (final b in body['banners'] as List<dynamic>)
          BannerDto.fromJson(b as Map<String, dynamic>).toDomain().target,
      ];
      expect(targets, [
        const BannerTarget.comic(ComicId(500540)),
        const BannerTarget.category(CategoryId('heroes')),
        const BannerTarget.search('amber'),
        const BannerTarget.category(CategoryId('cosmic')),
      ]);
    });

    test('T-0056-AC3 a target the contract does not allow is malformed', () {
      for (final bad in [
        const BannerTargetDto(type: 'comic'),
        const BannerTargetDto(type: 'category', comicId: 1),
        const BannerTargetDto(type: 'search', categoryId: 'heroes'),
        const BannerTargetDto(type: 'video', query: 'x'),
      ]) {
        expect(() => bad.toDomain(), throwsFormatException, reason: '$bad');
      }
    });

    test('T-0056-AC3 an unknown currency is malformed', () {
      const dto = CartSummaryDto(currency: 'XXX', itemCount: 1, totalCents: 1);
      expect(dto.toDomain, throwsFormatException);
    });
  });
}
