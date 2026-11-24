import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_paging/mc_paging.dart';
import 'package:test/test.dart';

void main() {
  group('T-0030-AC2 PagedState', () {
    test('T-0030-AC2: a new state is empty, idle and not at the end', () {
      const sut = PagedState<int>();

      expect(sut.items, isEmpty);
      expect(sut.request, const PageRequest(offset: 0, limit: 20));
      expect(sut.hasReachedEnd, isFalse);
      expect(sut.isLoadingMore, isFalse);
      expect(sut.failure, isNull);
      expect(sut.total, isNull);
    });

    test('T-0030-AC2: states with the same fields are equal', () {
      const failure = ApiFailure.offline();
      final a = const PagedState<int>().copyWith(items: [1, 2], total: 2);
      final b = const PagedState<int>().copyWith(items: [1, 2], total: 2);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(failure: failure), isNot(a));
    });
  });

  group('T-0030-AC1 Page and PageRequest', () {
    test('T-0030-AC1: requests compare by offset and limit', () {
      const sut = PageRequest(offset: 20, limit: 10);

      expect(sut, const PageRequest(offset: 20, limit: 10));
      expect(sut.hashCode, const PageRequest(offset: 20, limit: 10).hashCode);
      expect(sut, isNot(const PageRequest(offset: 0, limit: 10)));
      expect(sut, isNot(const PageRequest(offset: 20, limit: 5)));
      expect(sut.toString(), 'PageRequest(offset: 20, limit: 10)');
    });

    test('T-0030-AC1: a page describes itself without its items', () {
      const sut = Page<int>(offset: 0, limit: 20, total: 45, results: [1, 2]);

      expect(
        sut.toString(),
        'Page(offset: 0, limit: 20, total: 45, results: 2)',
      );
    });
  });
}
