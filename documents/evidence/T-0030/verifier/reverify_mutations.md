# T-0030 re-verification mutation diffs at b8d3abe (Verifier)

Prefixes: `r*` and `re-m*` = `paging_controller.dart`, `q*` = `debounced_query.dart`, `k*` = `search_history.dart`. The results are in the verification report, section "Re-verification at b8d3abe".

### mut-k1-clear-not-enqueued
```diff
@@ -34,7 +34,7 @@
 
   /// Removes every saved query, in order with pending [add] calls.
   Future<Result<void, StorageFailure>> clear() =>
-      _enqueue(() => _store.delete(key));
+      _store.delete(key);
 
   Future<R> _enqueue<R>(Future<R> Function() action) {
     final run = _tail.then((_) => action());
```
### mut-k2-load-no-cap
```diff
@@ -52,5 +52,5 @@
   }
 
   List<String> _decode(Object? json) =>
-      json is List ? json.whereType<String>().take(cap).toList() : <String>[];
+      json is List ? json.whereType<String>().toList() : <String>[];
 }
```
### mut-k3-corrupt-is-failure
```diff
@@ -21,7 +21,7 @@
   /// or unreadable value is an empty list, so the next [add] overwrites it.
   Future<Result<List<String>, StorageFailure>> load() async {
     final read = await _store.read(key);
-    return success(read.fold(_decode, (_) => <String>[]));
+    return read.map(_decode);
   }
 
   /// Moves [query] to the front. A blank query changes nothing. Adds and
```
### mut-k4-no-dedup
```diff
@@ -47,7 +47,7 @@
     if (text.isEmpty) {
       return success(saved);
     }
-    final updated = [text, ...saved.where((q) => q != text)].take(cap).toList();
+    final updated = [text, ...saved].take(cap).toList();
     return (await _store.write(key, updated)).map((_) => updated);
   }
 
```
### mut-k5-no-cap-on-add
```diff
@@ -47,7 +47,7 @@
     if (text.isEmpty) {
       return success(saved);
     }
-    final updated = [text, ...saved.where((q) => q != text)].take(cap).toList();
+    final updated = [text, ...saved.where((q) => q != text)].toList();
     return (await _store.write(key, updated)).map((_) => updated);
   }
 
```
### mut-q1-repeat-search
```diff
@@ -49,9 +49,6 @@
       }
       return;
     }
-    if (query == _searched) {
-      return;
-    }
     _timer = _timerFactory(delay, () {
       _timer = null;
       _searched = query;
```
### mut-q2-searched-set-at-schedule
```diff
@@ -52,9 +52,9 @@
     if (query == _searched) {
       return;
     }
+    _searched = query;
     _timer = _timerFactory(delay, () {
       _timer = null;
-      _searched = query;
       onSearch(query);
     });
   }
```
### mut-q3-no-dispose-guard
```diff
@@ -36,9 +36,6 @@
   /// for the previous query, so typing and deleting within the delay emits
   /// nothing. Does nothing after [dispose].
   void update(String text) {
-    if (_disposed) {
-      return;
-    }
     _timer?.cancel();
     _timer = null;
     final query = text.trim();
```
### mut-q4-no-cancel
```diff
@@ -39,7 +39,6 @@
     if (_disposed) {
       return;
     }
-    _timer?.cancel();
     _timer = null;
     final query = text.trim();
     if (query.isEmpty) {
```
### mut-r1-stale-clears-inflight
```diff
@@ -116,10 +116,10 @@
       }
       rethrow;
     }
+    _inFlight = false;
     if (generation != _generation) {
       return;
     }
-    _inFlight = false;
 
     result.fold(
       (page) {
```
### mut-r2-error-clears-inflight-unconditionally
```diff
@@ -111,9 +111,7 @@
     } on Object {
       // An Error is a bug, not a failed request: let it propagate, but do
       // not leave this run's request marked as in flight.
-      if (generation == _generation) {
-        _inFlight = false;
-      }
+      _inFlight = false;
       rethrow;
     }
     if (generation != _generation) {
```
### mut-r3-error-becomes-failure
```diff
@@ -106,7 +106,7 @@
     Result<Page<T>, ApiFailure> result;
     try {
       result = await _fetcher(request);
-    } on Exception catch (error) {
+    } on Object catch (error) {
       result = failure(ApiFailure.from(error));
     } on Object {
       // An Error is a bug, not a failed request: let it propagate, but do
```
### mut-r4a-no-dispose-guard-loadFirst
```diff
@@ -49,9 +49,6 @@
   /// Overlapping [loadFirst] and [refresh] calls: the last one wins. The
   /// earlier fetches are not cancelled; their responses are dropped.
   Future<void> loadFirst() async {
-    if (_disposed) {
-      return;
-    }
     _generation++;
     _failed = null;
     _emit(PagedState<T>(request: PageRequest(offset: 0, limit: limit)));
```
### mut-r4b-no-dispose-guard-refresh
```diff
@@ -62,9 +62,6 @@
   /// last of overlapping [loadFirst] and [refresh] calls wins (see
   /// [loadFirst]).
   Future<void> refresh() async {
-    if (_disposed) {
-      return;
-    }
     _generation++;
     _failed = null;
     await _run(PageRequest(offset: 0, limit: limit), replace: true);
```
### mut-r4c-no-dispose-guard-loadMore
```diff
@@ -73,8 +73,7 @@
   /// Loads the next page. Does nothing at the end, while a request is in
   /// flight, or after a failure (use [retry]).
   Future<void> loadMore() async {
-    if (_disposed ||
-        _state.hasReachedEnd ||
+    if (_state.hasReachedEnd ||
         _inFlight ||
         _state.failure != null) {
       return;
```
### mut-r4d-no-dispose-guard-retry
```diff
@@ -85,7 +85,7 @@
   /// Repeats the request that failed. Does nothing when nothing failed.
   Future<void> retry() async {
     final failed = _failed;
-    if (_disposed || failed == null || _inFlight) {
+    if (failed == null || _inFlight) {
       return;
     }
     await _run(failed.request, replace: failed.replace);
```
### mut-r5-results-not-copied
```diff
@@ -124,7 +124,7 @@
     result.fold(
       (page) {
         final items = replace
-            ? List<T>.of(page.results)
+            ? page.results
             : [..._state.items, ...page.results];
         final nextOffset = request.offset + page.results.length;
         _emit(
```
### mut-r6-unchecked-limit
```diff
@@ -22,7 +22,7 @@
     this.limit = 20,
   }) : _fetcher = fetcher,
        _state = PagedState<T>(
-         request: PageRequest.checked(offset: 0, limit: limit),
+         request: PageRequest(offset: 0, limit: limit),
        );
 
   final PageFetcher<T> _fetcher;
```
### mut-re-m1-no-end-guard
```diff
@@ -74,7 +74,6 @@
   /// flight, or after a failure (use [retry]).
   Future<void> loadMore() async {
     if (_disposed ||
-        _state.hasReachedEnd ||
         _inFlight ||
         _state.failure != null) {
       return;
```
### mut-re-m2-no-inflight-guard
```diff
@@ -75,7 +75,6 @@
   Future<void> loadMore() async {
     if (_disposed ||
         _state.hasReachedEnd ||
-        _inFlight ||
         _state.failure != null) {
       return;
     }
```
### mut-re-m3-retry-page1
```diff
@@ -88,7 +88,7 @@
     if (_disposed || failed == null || _inFlight) {
       return;
     }
-    await _run(failed.request, replace: failed.replace);
+    await _run(PageRequest(offset: 0, limit: limit), replace: true);
   }
 
   /// Drops any response still on its way and stops emitting.
```
### mut-re-m4-retry-append-nodedup
```diff
@@ -88,7 +88,7 @@
     if (_disposed || failed == null || _inFlight) {
       return;
     }
-    await _run(failed.request, replace: failed.replace);
+    await _run(PageRequest(offset: 0, limit: limit), replace: false);
   }
 
   /// Drops any response still on its way and stops emitting.
```
### mut-re-m5-no-stale-guard
```diff
@@ -116,9 +116,6 @@
       }
       rethrow;
     }
-    if (generation != _generation) {
-      return;
-    }
     _inFlight = false;
 
     result.fold(
```
### mut-re-m7-end-off-by-one
```diff
@@ -131,7 +131,7 @@
           _state.copyWith(
             items: items,
             request: PageRequest(offset: nextOffset, limit: limit),
-            hasReachedEnd: page.results.isEmpty || nextOffset >= page.total,
+            hasReachedEnd: page.results.isEmpty || nextOffset > page.total,
             isLoadingMore: false,
             failure: null,
             total: page.total,
```
### mut-re-m9-no-catch
```diff
@@ -106,8 +106,8 @@
     Result<Page<T>, ApiFailure> result;
     try {
       result = await _fetcher(request);
-    } on Exception catch (error) {
-      result = failure(ApiFailure.from(error));
+    } on FormatException catch (error) {
+      throw error;
     } on Object {
       // An Error is a bug, not a failed request: let it propagate, but do
       // not leave this run's request marked as in flight.
```
