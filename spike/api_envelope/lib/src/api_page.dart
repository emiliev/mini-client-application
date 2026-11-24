import 'package:json_annotation/json_annotation.dart';

part 'api_page.g.dart';

/// One page of a list endpoint (Tide's `data` container), nested inside
/// [ApiResponse] as `ApiResponse<ApiPage<T>>`.
@JsonSerializable(genericArgumentFactories: true)
class ApiPage<T> {
  const ApiPage({required this.offset, required this.limit, required this.total, required this.results});

  factory ApiPage.fromJson(Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$ApiPageFromJson(json, fromJsonT);

  final int offset;
  final int limit;
  final int total;
  final List<T> results;

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) => _$ApiPageToJson(this, toJsonT);
}
