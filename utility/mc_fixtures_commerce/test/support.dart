import 'package:dio/dio.dart';
import 'package:mc_fixtures_commerce/mc_fixtures_commerce.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// A backend serving the commerce domain (the default set).
MockBackend commerceBackend({
  int seed = 42,
  MockDomain domain = const CommerceMockDomain(),
}) => MockBackend(seed: seed, domains: [domain]);

/// A Dio that never throws on a status and returns the raw body text.
Dio plainDio(MockBackend backend) {
  final dio = backend.createDio();
  dio.options.validateStatus = (_) => true;
  dio.options.responseType = ResponseType.plain;
  return dio;
}

/// A Dio that never throws on a status and decodes JSON.
Dio jsonDio(MockBackend backend) =>
    backend.createDio()..options.validateStatus = (_) => true;

/// The bearer header of a valid access token for [userId].
Map<String, String> bearer(String userId, [int n = 1]) => {
  'Authorization': 'Bearer ${mintAccessToken(userId, n)}',
};

const String reader = 'u-100';
const String collector = 'u-101';

Future<Response<T>> call<T>(
  Dio dio,
  String method,
  String path, {
  Object? body,
  Map<String, String>? headers,
}) => dio.request<T>(
  path,
  data: body,
  options: Options(method: method, headers: headers),
);

typedef Json = Map<String, Object?>;

Future<Response<Json>> getJson(Dio dio, String path, {String? user}) =>
    call<Json>(dio, 'GET', path, headers: user == null ? null : bearer(user));

Future<Response<Json>> putQuantity(
  Dio dio,
  int productId,
  Object? quantity, {
  String user = reader,
}) => call<Json>(
  dio,
  'PUT',
  '/v1/me/cart/items/$productId',
  body: {'quantity': quantity},
  headers: bearer(user),
);

Future<Response<Json>> applyCode(
  Dio dio,
  Object? code, {
  String user = reader,
}) => call<Json>(
  dio,
  'POST',
  '/v1/me/cart/promo',
  body: {'code': code},
  headers: bearer(user),
);

/// A product as the store serves it, read through the API only.
typedef ProductView = ({
  int id,
  String title,
  String category,
  int listCents,
  int unitCents,
  int stock,
});

/// Every product of the store, read through the category endpoints (the unit
/// price is the deal price when `GET /v1/store/deals` lists the product).
Future<Map<int, ProductView>> loadProducts(Dio dio) async {
  final deals = <int, int>{};
  final dealBody = (await getJson(dio, '/v1/store/deals')).data!;
  for (final d in (dealBody['deals']! as List).cast<Json>()) {
    deals[(d['product']! as Json)['id']! as int] = d['dealPriceCents']! as int;
  }
  final categories = (await getJson(dio, '/v1/store/categories')).data!;
  final products = <int, ProductView>{};
  for (final c in (categories['categories']! as List).cast<Json>()) {
    final page = (await getJson(
      dio,
      '/v1/store/categories/${c['id']}/products?limit=100',
    )).data!;
    for (final p in (page['results']! as List).cast<Json>()) {
      final id = p['id']! as int;
      products[id] = (
        id: id,
        title: p['title']! as String,
        category: p['categoryId']! as String,
        listCents: p['priceCents']! as int,
        unitCents: deals[id] ?? p['priceCents']! as int,
        stock: p['stock']! as int,
      );
    }
  }
  return products;
}

/// Products of [category] with at least [minStock] in stock, by id.
List<ProductView> inCategory(
  Map<int, ProductView> products,
  String category, {
  int minStock = 1,
}) => [
  for (final p in products.values)
    if (p.category == category && p.stock >= minStock) p,
]..sort((a, b) => a.id.compareTo(b.id));
