# F-0030: Drawing real images in widget tests under Bazel, and how a paged list sees "nothing to scroll"

- **Date:** 2026-11-25
- **Author:** crew: Engineer (T-0031)
- **Type:** Gotcha
- **Related:** T-0031-AC3, T-0031-AC4, F-0014, F-0029

## Summary
1. **The tester has no asset bundle under Bazel.** `AssetImage` needs the app bundle, and a `flutter_test` target in Bazel does not provide one. `mc_test_utils` now has `McFixtureAssetBundle` (a `CachingAssetBundle` that reads `mc_fixtures_media` PNGs from runfiles or the checkout) and `mcPrecacheFixtureImages`. A test target lists `//utility/mc_fixtures_media:asset_files` in `data`, wraps the app in `DefaultAssetBundle` (`mcGoldenApp(bundle:)`, `mcGoldenMatrix(assetBundle:, precache:)`). The bundle answers `AssetManifest.bin` with an empty map, so every asset is its own 1x file.
2. **Decoding is real async work and cannot finish under `FakeAsync`.** Goldens must call `mcPrecacheFixtureImages` (inside `tester.runAsync`) before the first `pumpWidget`; the first frame then draws the picture (`wasSynchronouslyLoaded` is true, so no cross-fade). The `ImageCache` key is (bundle instance, name, scale), so the same `McFixtureAssetBundle` instance must serve both the precache and the widget tree.
3. **Testing "placeholder first, image later".** Give the bundle a `gate` future, pump (placeholder shows), complete the gate, `pump()`, then loop `runAsync(delay 10 ms)` + `pump()` until the loaded key appears. The loop is bounded (200 rounds) and the test fails if the image never arrives; it waits for a real decode, it does not retry an assertion.
4. **`ScrollMetricsNotification` is not a `ScrollNotification`.** A `NotificationListener<ScrollNotification>` never sees it. A paged list whose content does not fill the viewport has `maxScrollExtent == 0`, so no scroll ever happens and only the metrics notification (sent after layout, so it is safe to call the owner) can trigger the next page. `PagedBody` listens to both and tests it (`a list shorter than the viewport asks once`).
5. **The load-more guard lives in the widget.** `onLoadMore` fires at most once per distinct `PagedState`: the widget keeps a flag cleared in `didUpdateWidget` when the state differs. A burst of scroll events before the owner emits a new state (a bloc may take a frame) therefore asks once. It never fires at the end, while loading, after a failure (Retry is the way out), or before the first item exists (the owner calls `loadFirst`).
6. **A spinner footer prevents `pumpAndSettle`.** With `isLoadingMore` the `CircularProgressIndicator` animates forever; tests that fling to the end pump 100 ms steps instead. A single large `pump(2 s)` leaves the `BouncingScrollPhysics` ballistic mid-bounce (pixels past `maxScrollExtent`).
7. **A grid cell with text needs a height that follows the text scale.** `McPagedGrid` takes `cellHeight(cellWidth, textScaler)`; `McMediaCard.heightFor` is the matching function. A fixed `childAspectRatio` overflows the title at 2x. `heightFor` is verified by the 8-golden-variant matrix and by `card_test` at scales 1, 2 and 3.

## Implications / actions
- `McMediaScope` lives in `mc_ds_media`; `mc_media` is pure Dart with one barrel (F-0029 follow-up done).
- `mc_ds_media` depends on `mc_fixtures_media` for `BundledImage` (the bundled `assetKey` to `AssetImage` path). When a network resolver arrives, `mcImageProviderFor` gets a second case, and the bundled one can move behind a registry so a production DS package stops depending on fixtures (follow-up).
- Other golden packages that want real art use the same two helpers.
