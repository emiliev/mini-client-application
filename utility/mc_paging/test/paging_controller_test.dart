import 'dart:async';

import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_paging/mc_paging.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:test/test.dart';

/// A backend of [total] ints. Records every request. Pages listed in
/// [failOffsets] fail once each; [gate], when set, holds responses back.
class _FakeBackend {
  _FakeBackend(this.total);

  final int total;
  final requests = <PageRequest>[];
  final failOffsets = <int>{};
  Completer<void>? gate;
  Object? throwOnNext;

  Future<Result<Page<int>, ApiFailure>> fetch(PageRequest request) async {
    requests.add(request);
    final held = gate;
    if (held != null) {
      await held.future;
    }
    final toThrow = throwOnNext;
    if (toThrow != null) {
      throwOnNext = null;
      throw toThrow;
    }
    if (failOffsets.remove(request.offset)) {
      return failure(const ApiFailure.server(503));
    }
    final end = (request.offset + request.limit).clamp(0, total);
    return success(
      Page(
        offset: request.offset,
        limit: request.limit,
        total: total,
        results: [for (var i = request.offset; i < end; i++) i],
      ),
    );
  }
}

({PagingController<int> sut, _FakeBackend backend, List<PagedState<int>> seen})
_make({int total = 45, int limit = 20}) {
  final backend = _FakeBackend(total);
  final seen = <PagedState<int>>[];
  final sut = PagingController<int>(
    fetcher: backend.fetch,
    onState: seen.add,
    limit: limit,
  );
  return (sut: sut, backend: backend, seen: seen);
}

void main() {
  group('T-0030-AC1 loading pages', () {
    test('T-0030-AC1: loadFirst then loadMore twice reads all 45 items', () async {
      final (:sut, :backend, seen: _) = _make();

      await sut.loadFirst();
      await sut.loadMore();
      await sut.loadMore();

      expect(backend.requests.map((r) => r.offset), [0, 20, 40]);
      expect(backend.requests.map((r) => r.limit), [20, 20, 20]);
      expect(sut.state.items, List.generate(45, (i) => i));
      expect(sut.state.hasReachedEnd, isTrue);
      expect(sut.state.total, 45);
      expect(sut.state.isLoadingMore, isFalse);
      expect(sut.state.failure, isNull);
    });

    test('T-0030-AC1: the first request reports loading before items', () async {
      final (:sut, backend: _, :seen) = _make();

      await sut.loadFirst();

      expect(seen.first.items, isEmpty);
      expect(seen[1].isLoadingMore, isTrue);
      expect(seen.last.isLoadingMore, isFalse);
      expect(seen.last.items, hasLength(20));
    });

    test('T-0030-AC1: an empty page ends the list', () async {
      final (:sut, :backend, seen: _) = _make(total: 0);

      await sut.loadFirst();

      expect(backend.requests, hasLength(1));
      expect(sut.state.items, isEmpty);
      expect(sut.state.hasReachedEnd, isTrue);
    });

    test('T-0030-AC1: loadFirst again starts over from offset 0', () async {
      final (:sut, :backend, seen: _) = _make();
      await sut.loadFirst();
      await sut.loadMore();

      await sut.loadFirst();

      expect(backend.requests.map((r) => r.offset), [0, 20, 0]);
      expect(sut.state.items, List.generate(20, (i) => i));
      expect(sut.state.hasReachedEnd, isFalse);
    });

    test('T-0030-AC1: refresh keeps items while loading, then replaces', () async {
      final (:sut, :backend, :seen) = _make();
      await sut.loadFirst();
      await sut.loadMore();
      seen.clear();

      await sut.refresh();

      expect(seen.first.items, hasLength(40));
      expect(seen.first.isLoadingMore, isTrue);
      expect(sut.state.items, List.generate(20, (i) => i));
      expect(backend.requests.last.offset, 0);
    });
  });

  group('T-0030-AC2 guards', () {
    test('T-0030-AC2: loadMore at the end makes no request', () async {
      final (:sut, :backend, seen: _) = _make(total: 25);
      await sut.loadFirst();
      await sut.loadMore();
      expect(sut.state.hasReachedEnd, isTrue);
      final before = backend.requests.length;

      await sut.loadMore();

      expect(backend.requests, hasLength(before));
    });

    test('T-0030-AC2: loadMore while one is in flight makes no second request', () async {
      final (:sut, :backend, seen: _) = _make();
      await sut.loadFirst();
      backend.gate = Completer<void>();

      final first = sut.loadMore();
      final second = sut.loadMore();
      backend.gate!.complete();
      await Future.wait([first, second]);

      expect(backend.requests.map((r) => r.offset), [0, 20]);
      expect(sut.state.items, hasLength(40));
    });

    test('T-0030-AC2: retry while loading makes no second request', () async {
      final (:sut, :backend, seen: _) = _make();
      backend.failOffsets.add(0);
      await sut.loadFirst();
      backend.gate = Completer<void>();

      final first = sut.retry();
      final second = sut.retry();
      backend.gate!.complete();
      await Future.wait([first, second]);

      expect(backend.requests.map((r) => r.offset), [0, 0]);
    });
  });

  group('T-0030-AC3 failures', () {
    test('T-0030-AC3: a failing second page keeps page one and exposes the failure', () async {
      final (:sut, :backend, seen: _) = _make();
      await sut.loadFirst();
      backend.failOffsets.add(20);

      await sut.loadMore();

      expect(sut.state.items, List.generate(20, (i) => i));
      expect(sut.state.failure, isA<ApiServer>());
      expect(sut.state.isLoadingMore, isFalse);
      expect(sut.state.hasReachedEnd, isFalse);
    });

    test('T-0030-AC3: retry requests only the failed page and appends once', () async {
      final (:sut, :backend, seen: _) = _make();
      await sut.loadFirst();
      backend.failOffsets.add(20);
      await sut.loadMore();

      await sut.retry();

      expect(backend.requests.map((r) => r.offset), [0, 20, 20]);
      expect(sut.state.items, List.generate(40, (i) => i));
      expect(sut.state.failure, isNull);
    });

    test('T-0030-AC3: loadMore after a failure waits for retry', () async {
      final (:sut, :backend, seen: _) = _make();
      await sut.loadFirst();
      backend.failOffsets.add(20);
      await sut.loadMore();

      await sut.loadMore();

      expect(backend.requests, hasLength(2));
    });

    test('T-0030-AC3: retry with no failure makes no request', () async {
      final (:sut, :backend, seen: _) = _make();
      await sut.loadFirst();

      await sut.retry();

      expect(backend.requests, hasLength(1));
    });

    test('T-0030-AC3: a failing first page leaves no items and retry loads it', () async {
      final (:sut, :backend, seen: _) = _make();
      backend.failOffsets.add(0);

      await sut.loadFirst();
      expect(sut.state.items, isEmpty);
      expect(sut.state.failure, isNotNull);
      await sut.retry();

      expect(sut.state.items, hasLength(20));
      expect(backend.requests.map((r) => r.offset), [0, 0]);
    });

    test('T-0030-AC3: a failing refresh keeps items and retry replaces them', () async {
      final (:sut, :backend, seen: _) = _make();
      await sut.loadFirst();
      await sut.loadMore();
      backend.failOffsets.add(0);

      await sut.refresh();
      expect(sut.state.items, hasLength(40));
      expect(sut.state.failure, isNotNull);
      await sut.retry();

      expect(sut.state.items, List.generate(20, (i) => i));
      expect(sut.state.failure, isNull);
    });

    test('T-0030-AC3: a fetcher that throws becomes an ApiFailure', () async {
      final (:sut, :backend, seen: _) = _make();
      backend.throwOnNext = const FormatException('bad json');

      await sut.loadFirst();

      expect(sut.state.failure, isA<ApiMalformed>());
    });
  });

  group('T-0030-AC2 stale responses', () {
    test('T-0030-AC2: a response from before loadFirst is dropped', () async {
      final (:sut, :backend, :seen) = _make();
      final gate = Completer<void>();
      backend.gate = gate;
      final stale = sut.loadFirst();
      backend.gate = null;
      await sut.loadFirst();
      final emitted = seen.length;

      gate.complete();
      await stale;

      expect(seen, hasLength(emitted));
      expect(sut.state.items, hasLength(20));
      expect(backend.requests.map((r) => r.offset), [0, 0]);
    });

    test('T-0030-AC2: dispose stops emitting and drops the response', () async {
      final (:sut, :backend, :seen) = _make();
      backend.gate = Completer<void>();
      final pending = sut.loadFirst();
      final emitted = seen.length;

      sut.dispose();
      backend.gate!.complete();
      await pending;

      expect(seen, hasLength(emitted));
    });
  });
}
