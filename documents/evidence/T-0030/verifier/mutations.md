# T-0030 mutation diffs (Verifier)

Each mutation was applied with `perl`, run with `test --nocache_test_results` on the mapped target, and then restored from a copy. All 23 turned the suite red; the [verification report](../verification-report.md) names the test that caught each one.

| Prefix | File |
|---|---|
| `m*` | `utility/mc_paging/lib/src/paging_controller.dart` |
| `d*` | `utility/mc_paging/lib/src/query/debounced_query.dart` |
| `h*` | `utility/mc_paging/lib/src/query/search_history.dart` |
| `s*` | `utility/mc_media/lib/src/media_scope.dart` |
| `p1` | `utility/mc_paging/lib/src/page.dart` |
| `p2` | `utility/mc_media/lib/src/image_resolver.dart` |

### mut-d1-no-cancel
```diff
@@ -30,7 +30,6 @@
 
   /// The field's current text.
   void update(String text) {
-    _timer?.cancel();
     _timer = null;
     final query = text.trim();
     if (query.isEmpty) {
```
### mut-d2-clear-is-search
```diff
@@ -33,7 +33,7 @@
     _timer?.cancel();
     _timer = null;
     final query = text.trim();
-    if (query.isEmpty) {
+    if (false) {
       if (_hasQuery) {
         _hasQuery = false;
         onClear();
```
### mut-d3-dispose-noop
```diff
@@ -49,7 +49,6 @@
 
   /// Cancels a pending search.
   void dispose() {
-    _timer?.cancel();
     _timer = null;
   }
 }
```
### mut-d4-no-trim
```diff
@@ -32,7 +32,7 @@
   void update(String text) {
     _timer?.cancel();
     _timer = null;
-    final query = text.trim();
+    final query = text;
     if (query.isEmpty) {
       if (_hasQuery) {
         _hasQuery = false;
```
### mut-h1-no-dedup
```diff
@@ -38,7 +38,7 @@
       }
       final updated = [
         text,
-        ...saved.where((q) => q != text),
+        ...saved,
       ].take(cap).toList();
       return (await _store.write(key, updated)).map((_) => updated);
     });
```
### mut-h2-no-cap
```diff
@@ -39,7 +39,7 @@
       final updated = [
         text,
         ...saved.where((q) => q != text),
-      ].take(cap).toList();
+      ].toList();
       return (await _store.write(key, updated)).map((_) => updated);
     });
   }
```
### mut-h3-append-end
```diff
@@ -37,8 +37,8 @@
         return success(saved);
       }
       final updated = [
-        text,
         ...saved.where((q) => q != text),
+        text,
       ].take(cap).toList();
       return (await _store.write(key, updated)).map((_) => updated);
     });
```
### mut-h4-no-serialise
```diff
@@ -22,7 +22,7 @@
   /// serialised, so overlapping calls keep every query.
   Future<Result<List<String>, StorageFailure>> add(String query) {
     final text = query.trim();
-    final run = _tail.then((_) => _add(text));
+    final run = _add(text);
     _tail = run.then<void>((_) {}, onError: (Object _) {});
     return run;
   }
```
### mut-m1-no-end-guard
```diff
@@ -62,7 +62,7 @@
   /// Loads the next page. Does nothing at the end, while a request is in
   /// flight, or after a failure (use [retry]).
   Future<void> loadMore() async {
-    if (_state.hasReachedEnd || _inFlight || _state.failure != null) {
+    if (_inFlight || _state.failure != null) {
       return;
     }
     await _run(_state.request, replace: false);
```
### mut-m2-no-inflight-guard
```diff
@@ -62,7 +62,7 @@
   /// Loads the next page. Does nothing at the end, while a request is in
   /// flight, or after a failure (use [retry]).
   Future<void> loadMore() async {
-    if (_state.hasReachedEnd || _inFlight || _state.failure != null) {
+    if (_state.hasReachedEnd || _state.failure != null) {
       return;
     }
     await _run(_state.request, replace: false);
```
### mut-m3-retry-page1
```diff
@@ -74,7 +74,7 @@
     if (failed == null || _inFlight) {
       return;
     }
-    await _run(failed.request, replace: failed.replace);
+    await _run(PageRequest(offset: 0, limit: limit), replace: true);
   }
 
   /// Drops any response still on its way and stops emitting.
```
### mut-m4-retry-append-nodedup
```diff
@@ -74,7 +74,7 @@
     if (failed == null || _inFlight) {
       return;
     }
-    await _run(failed.request, replace: failed.replace);
+    await _run(PageRequest(offset: 0, limit: limit), replace: false);
   }
 
   /// Drops any response still on its way and stops emitting.
```
### mut-m4b-dup-items-same-requests
```diff
@@ -104,7 +104,7 @@
       (page) {
         final items = replace
             ? page.results
-            : [..._state.items, ...page.results];
+            : [..._state.items, ...page.results, ...page.results.take(1)];
         final nextOffset = request.offset + page.results.length;
         _emit(
           _state.copyWith(
```
### mut-m5-no-stale-guard
```diff
@@ -95,9 +95,7 @@
     } on Object catch (error) {
       result = failure(ApiFailure.from(error));
     }
-    if (generation != _generation) {
-      return;
-    }
+    if (false) {}
     _inFlight = false;
 
     result.fold(
```
### mut-m6-no-failure-guard
```diff
@@ -62,7 +62,7 @@
   /// Loads the next page. Does nothing at the end, while a request is in
   /// flight, or after a failure (use [retry]).
   Future<void> loadMore() async {
-    if (_state.hasReachedEnd || _inFlight || _state.failure != null) {
+    if (_state.hasReachedEnd || _inFlight) {
       return;
     }
     await _run(_state.request, replace: false);
```
### mut-m7-end-off-by-one
```diff
@@ -110,7 +110,7 @@
           _state.copyWith(
             items: items,
             request: PageRequest(offset: nextOffset, limit: limit),
-            hasReachedEnd: page.results.isEmpty || nextOffset >= page.total,
+            hasReachedEnd: page.results.isEmpty || nextOffset > page.total,
             isLoadingMore: false,
             failure: null,
             total: page.total,
```
### mut-m8-retry-ignores-replace
```diff
@@ -74,7 +74,7 @@
     if (failed == null || _inFlight) {
       return;
     }
-    await _run(failed.request, replace: failed.replace);
+    await _run(failed.request, replace: false);
   }
 
   /// Drops any response still on its way and stops emitting.
```
### mut-m9-no-catch
```diff
@@ -90,11 +90,7 @@
     _emit(_state.copyWith(isLoadingMore: true, failure: null));
 
     Result<Page<T>, ApiFailure> result;
-    try {
-      result = await _fetcher(request);
-    } on Object catch (error) {
-      result = failure(ApiFailure.from(error));
-    }
+    result = await _fetcher(request);
     if (generation != _generation) {
       return;
     }
```
### mut-p1-handwritten-mixin
```diff
@@ -1,3 +1,5 @@
+mixin _Probe {}
+
 /// Which slice of a list to fetch.
 final class PageRequest {
   const PageRequest({required this.offset, required this.limit});
```
### mut-p2-flutter-import-pure-media
```diff
@@ -1,3 +1,4 @@
+import 'package:flutter/foundation.dart';
 import 'package:mc_media/src/api_image.dart';
 
 /// What an [McImageResolver] resolved an [ApiImage] to. Implementations add
```
### mut-s1-of-stateerror
```diff
@@ -12,7 +12,7 @@
   static McImageResolver of(BuildContext context) {
     final scope = context.dependOnInheritedWidgetOfExactType<McMediaScope>();
     if (scope == null) {
-      throw FlutterError(
+      throw StateError(
         'McMediaScope.of() called with a context that has no McMediaScope '
         'above it.\nWrap the app in McMediaScope(resolver: ...).',
       );
```
### mut-s2-of-wrong-name
```diff
@@ -13,8 +13,7 @@
     final scope = context.dependOnInheritedWidgetOfExactType<McMediaScope>();
     if (scope == null) {
       throw FlutterError(
-        'McMediaScope.of() called with a context that has no McMediaScope '
-        'above it.\nWrap the app in McMediaScope(resolver: ...).',
+        'No media scope found.',
       );
     }
     return scope.resolver;
```
### mut-s3-notify-always
```diff
@@ -22,5 +22,5 @@
 
   @override
   bool updateShouldNotify(McMediaScope oldWidget) =>
-      resolver != oldWidget.resolver;
+      true;
 }
```
