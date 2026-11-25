import 'package:json_annotation/json_annotation.dart';

part 'api_page.g.dart';

/// One page of a list endpoint, as the backend sends it: the request's
/// `offset` and `limit`, the `total` of all matches, the `count` in this page
/// and the `results` (the mocked backend's `pageEnvelope`, CONTRACT.md).
///
/// Generic through json_serializable's `genericArgumentFactories`, so a
/// feature's retrofit API returns `ApiPage<CharacterDto>` and retrofit passes
/// the `fromJsonT` for the item type. The contract has no `{code, data}`
/// wrapper around it, so there is no `ApiResponse<T>` (T-0032).
@JsonSerializable(genericArgumentFactories: true)
class ApiPage<T> {
  const ApiPage({
    required this.offset,
    required this.limit,
    required this.total,
    required this.count,
    required this.results,
  });

  factory ApiPage.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) => _$ApiPageFromJson(json, fromJsonT);

  final int offset;
  final int limit;

  /// How many items match the whole query, not this page.
  final int total;

  /// `results.length`, as the backend reports it.
  final int count;
  final List<T> results;

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$ApiPageToJson(this, toJsonT);
}
