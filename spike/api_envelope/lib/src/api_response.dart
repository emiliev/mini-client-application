import 'package:json_annotation/json_annotation.dart';

part 'api_response.g.dart';

/// The envelope every endpoint returns (Tide's `MarvelResponse<T>`):
/// `genericArgumentFactories`, so retrofit passes a `fromJsonT` for `T`.
@JsonSerializable(genericArgumentFactories: true)
class ApiResponse<T> {
  const ApiResponse({
    required this.code,
    required this.status,
    required this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) => _$ApiResponseFromJson(json, fromJsonT);

  final int code;
  final String status;
  final T data;

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$ApiResponseToJson(this, toJsonT);
}
