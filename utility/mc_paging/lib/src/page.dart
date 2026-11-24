/// Which slice of a list to fetch.
final class PageRequest {
  const PageRequest({required this.offset, required this.limit});

  /// Like the constructor, but throws an [ArgumentError] (in release builds
  /// too) for a negative [offset] or a [limit] of zero or less.
  factory PageRequest.checked({required int offset, required int limit}) {
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'must not be negative');
    }
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    return PageRequest(offset: offset, limit: limit);
  }

  final int offset;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is PageRequest && other.offset == offset && other.limit == limit;

  @override
  int get hashCode => Object.hash(offset, limit);

  @override
  String toString() => 'PageRequest(offset: $offset, limit: $limit)';
}

/// One page as the backend sends it: `offset`, `limit`, `total` and
/// `results` (the paging contract of the mocked backend).
final class Page<T> {
  const Page({
    required this.offset,
    required this.limit,
    required this.total,
    required this.results,
  });

  final int offset;
  final int limit;

  /// How many items match in all, not in this page.
  final int total;
  final List<T> results;

  @override
  String toString() =>
      'Page(offset: $offset, limit: $limit, total: $total, '
      'results: ${results.length})';
}
