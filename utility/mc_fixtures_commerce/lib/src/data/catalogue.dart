import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The one currency of the store.
const String currencyCode = 'EUR';

/// A comic is sold when its issue number is at most this (3 per series).
const int issuesSold = 3;

/// Money is integer cents everywhere. The one place a percentage is applied:
/// `cents * percent / 100`, rounded half-up (for non-negative [cents]), in
/// integer arithmetic only.
int percentOfHalfUp(int cents, int percent) => (cents * percent + 50) ~/ 100;

/// A store category. A comic is in category `series index % 6`.
final class CategoryDef {
  const CategoryDef(this.id, this.name, this.imageIndex);

  final String id;
  final String name;

  /// The placeholder image (`mock-asset://characters/<n>`).
  final int imageIndex;
}

const List<CategoryDef> categoryDefs = [
  CategoryDef('heroes', 'Heroes', 2),
  CategoryDef('villains', 'Villains', 6),
  CategoryDef('cosmic', 'Cosmic', 10),
  CategoryDef('mystery', 'Mystery', 14),
  CategoryDef('classics', 'Classics', 18),
  CategoryDef('team-ups', 'Team-Ups', 22),
];

/// Catalogue positions (in comic title order) of the deals and their percent
/// off. None is out of stock.
const List<int> dealPositions = [7, 48, 89, 130, 171, 212, 253, 294];
const List<int> dealPercents = [10, 15, 20, 25, 30, 35, 40, 50];

/// Catalogue positions of the featured products.
const List<int> featuredPositions = [3, 56, 109, 162, 215, 268];

/// Every 11th product from position 5 is out of stock.
const int outOfStockModulus = 11;
const int outOfStockRemainder = 5;

/// Every 7th product has a large stock (above the 99 maximum quantity).
const int plentyModulus = 7;
const int plentyStock = 120;

final class Deal {
  const Deal({
    required this.discountPercent,
    required this.dealPriceCents,
    required this.endsInDays,
  });

  final int discountPercent;
  final int dealPriceCents;

  /// The deal ends this many days after the backend's fixed clock.
  final int endsInDays;
}

/// One product: a comic with a store price and a stock.
final class Product {
  const Product({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.issueNumber,
    required this.seriesId,
    required this.priceCents,
    required this.stock,
    required this.cover,
    this.deal,
  });

  /// The comic id (`GET /v1/comics/{id}`).
  final int id;
  final String title;
  final String categoryId;
  final int issueNumber;
  final int seriesId;
  final int priceCents;
  final int stock;
  final ApiImage cover;
  final Deal? deal;

  /// What the cart charges for one unit: the deal price when there is a deal.
  int get unitPriceCents => deal?.dealPriceCents ?? priceCents;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'categoryId': categoryId,
    'issueNumber': issueNumber,
    'seriesId': seriesId,
    'priceCents': priceCents,
    'dealPriceCents': deal?.dealPriceCents,
    'currency': currencyCode,
    'stock': stock,
    'cover': cover.toJson(),
  };

  Map<String, Object?> toDealJson(DateTime clock) => {
    'product': toJson(),
    'originalPriceCents': priceCents,
    'dealPriceCents': deal!.dealPriceCents,
    'discountPercent': deal!.discountPercent,
    'currency': currencyCode,
    'endsAt': clock.add(Duration(days: deal!.endsInDays)).toIso8601String(),
  };
}

/// The store's catalogue for one seed: products, categories, banners, deals
/// and the featured list.
final class Catalogue {
  Catalogue._(this.products, this.banners)
    : byId = {for (final p in products) p.id: p};

  /// A store with nothing in it (the `commerce.empty` set).
  Catalogue.empty() : this._(const [], const []);

  factory Catalogue.build(int seed) {
    final universe = ComicUniverse(seed);
    final random = SplitMix64(seed).fork('commerce').fork('price');
    final products = <Product>[];
    for (final comic in universe.byTitle) {
      if (comic.issueNumber > issuesSold) {
        continue;
      }
      final position = products.length;
      final rng = random.fork('${comic.id}');
      final price = 299 + rng.nextInt(1701);
      final stock = position % outOfStockModulus == outOfStockRemainder
          ? 0
          : position % plentyModulus == 0
          ? plentyStock
          : 3 + rng.nextInt(38);
      final dealAt = dealPositions.indexOf(position);
      products.add(
        Product(
          id: comic.id,
          title: comic.title,
          categoryId:
              categoryDefs[(comic.seriesId - 400000) % categoryDefs.length].id,
          issueNumber: comic.issueNumber,
          seriesId: comic.seriesId,
          priceCents: price,
          stock: stock,
          cover: comic.cover,
          deal: dealAt < 0
              ? null
              : Deal(
                  discountPercent: dealPercents[dealAt],
                  dealPriceCents:
                      price - percentOfHalfUp(price, dealPercents[dealAt]),
                  endsInDays: dealAt + 1,
                ),
        ),
      );
    }
    ApiImage image(int index, ImageVariant variant) => ApiImage(
      path: 'mock-asset://characters/${index.toString().padLeft(3, '0')}',
      variant: variant,
    );
    return Catalogue._(products, [
      {
        'id': 'b-1',
        'title': 'New this week',
        'subtitle': 'Fresh first issues, picked for you',
        'image': image(1, ImageVariant.landscape).toJson(),
        'target': {'type': 'comic', 'comicId': products[12].id},
      },
      {
        'id': 'b-2',
        'title': 'Heroes assemble',
        'subtitle': 'Buy 2 get 1 with HEROES3',
        'image': image(5, ImageVariant.landscape).toJson(),
        'target': {'type': 'category', 'categoryId': 'heroes'},
      },
      {
        'id': 'b-3',
        'title': 'Amber season',
        'subtitle': 'Every Amber series in one search',
        'image': image(9, ImageVariant.landscape).toJson(),
        'target': {'type': 'search', 'query': 'amber'},
      },
      {
        'id': 'b-4',
        'title': 'Out of this world',
        'subtitle': 'Cosmic adventures, buy 2 get 1 with COSMIC3',
        'image': image(13, ImageVariant.landscape).toJson(),
        'target': {'type': 'category', 'categoryId': 'cosmic'},
      },
    ]);
  }

  /// Every product, in comic title order.
  final List<Product> products;
  final Map<int, Product> byId;

  /// The banners as served (a banner has no clock-dependent field).
  final List<Map<String, Object?>> banners;

  bool get isEmpty => products.isEmpty;

  /// The categories shown: none for an empty store.
  List<CategoryDef> get categories => isEmpty ? const [] : categoryDefs;

  CategoryDef? category(String id) {
    for (final c in categories) {
      if (c.id == id) {
        return c;
      }
    }
    return null;
  }

  List<Product> productsOf(String categoryId) => [
    for (final p in products)
      if (p.categoryId == categoryId) p,
  ];

  List<Product> get deals => [
    for (final p in products)
      if (p.deal != null) p,
  ];

  List<Product> get featured =>
      isEmpty ? const [] : [for (final at in featuredPositions) products[at]];
}

final Map<int, Catalogue> _catalogues = {};
final Catalogue _emptyCatalogue = Catalogue.empty();

/// The catalogue of [seed] (built once per seed, at request time, so a
/// scenario follows the backend's own seed), or the empty one.
Catalogue catalogueFor(int seed, {required bool empty}) =>
    empty ? _emptyCatalogue : _catalogues[seed] ??= Catalogue.build(seed);
