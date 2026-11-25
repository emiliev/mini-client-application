# T-0031: Design-system lists, media and cards for LD (P1-12 subset: `mc_ds_media`, `mc_ds_lists`, `mc_ds_cards`)

| Field | Value |
|---|---|
| Status | In Progress (branched from T-0030 head `63dbaf4`; merges `origin/main` after T-0030) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0031-ds-lists-media-cards` |
| Created | 2026-11-25 |
| Depends on | T-0019 (DS foundation), T-0026 (`mc_test_utils` goldens), T-0030 (`mc_paging`, `mc_media`) |
| Related | [plan 01 U29, U31, P1-12, §3.3](../plan/01-architecture-and-modules.md), ADR-0007, ADR-0010, F-0014 (goldens under Bazel), F-0029 (`mc_media` split) |

## Goal
The design-system widgets the `characters_list` exemplar (P1-17) renders: a paged grid and list bound to `PagedState`, a resolver-based `McImage`, and the media card a character tile is built from. Features don't hand-roll any of these.

## Scope
- **In:**
  - `utility/mc_ds_media` (U29). It contains:
    - `McImage(image: ApiImage, variant:)`: it resolves through `McMediaScope`, shows a placeholder while resolving, cross-fades to the image, and shows a fallback on error.
    - `McAvatar`.
    - `McMediaScope`, **moved here** from `mc_media` (TL decision, T-0030). After the move, `mc_media` is pure Dart with a single barrel again, so delete `mc_media_scope.dart` and update the references.
    - The bundled-asset path: `BundledImage.assetKey` → `AssetImage`.
  - `utility/mc_ds_lists` (U31). It contains:
    - `McPagedGrid<T>` and `McPagedList<T>`, bound to `PagedState<T>`, with `itemBuilder`, `onLoadMore`, `onRetry` and `onRefresh`.
    - Both request the next page once when scrolled past 80 %, and never at the end or while a load is in flight.
    - A footer shows the loading row, or an inline error with Retry (`mc_ds_feedback`).
    - Pull to refresh, using the iOS style.
    - An empty state.
    - Responsive columns from `mc_ds_layout` breakpoints.
  - `utility/mc_ds_cards`. It contains `McMediaCard`: an image, a title, an optional subtitle and an `onTap`, with semantics (button, label), plus a skeleton variant for loading.
  - Goldens through the `mc_test_utils` harness, not the `mc_ds_testing` shim. Cover the 4 themes (light, dark, and both high-contrast variants) × 2 text scales, as T-0019 did. Use real fonts and bundled art from `mc_fixtures_media` as the images.
- **Out:**
  - The `ds_catalog` app and its screenshots (P1-12 AC4).
  - Carousel, gallery and zoom.
  - `mc_ds_navigation`.
  - `mc_analytics`.

## Acceptance criteria
- **T-0031-AC1:** Given `McPagedGrid` over a `PagedState` with 20 items and more to load, when it is scrolled to 80 %, then `onLoadMore` is called exactly once, including across further scroll events before the state changes. Given `hasReachedEnd`, or a load in flight, then scrolling to the bottom calls it zero times. Prove the same for `McPagedList`. (P1-12 AC2.)
- **T-0031-AC2:** Given a `PagedState` with items and a failure, then the footer shows an inline error, the items stay visible, and tapping Retry calls `onRetry` once. Given an empty, settled state, then the empty view shows. Given a first load in progress, then the skeleton cards show.
- **T-0031-AC3:** Given `McImage` with a resolver that completes later, then the placeholder shows first and the resolved bundled image after. Given an `UnresolvedImageException`, then the fallback shows and nothing throws. Given no `McMediaScope`, then a clear `FlutterError` names it. (P1-12 AC3.)
- **T-0031-AC4:** Goldens exist for `McPagedGrid` (loading, loaded, error footer, empty), `McMediaCard` (normal, long title, skeleton) and `McImage` (placeholder, image, fallback), in the 4 themes × 2 text scales, with real fonts and real fixture art. A long title at the large text scale doesn't overflow. (P1-12 AC1 subset.)
- **T-0031-AC5:** `McMediaCard` exposes a button role and its title as the label. The tap target is ≥ 44 pt. Images are excluded from semantics unless they have a label.
- **T-0031-AC6:**
  - `McMediaScope` now lives in `mc_ds_media`, and `mc_media` has one pure-Dart barrel. Re-run the T-0030 closure check; it still passes.
  - All three packages are registered in the workspace and pass `mc_arch_check`.
  - Coverage is ≥ 90 % per package.
  - `test //...`, `build --config=lint //...` and `rules_fork.sh check` are green.

## Notes for the Engineer
- Read `CLAUDE.md`, `documents/STATUS.md`, `documents/fleet/protocol.md`, ADR-0007, ADR-0010, F-0014, F-0029 and T-0019's task and evidence (the golden setup). Copy the package shape from `utility/mc_ds_feedback` and `utility/mc_ds_layout`.
- Bazel: always use `tool/bazelw --output_base=/tmp/mc-ob-T-0031-engineer`.
- Scroll tests use `tester.drag` or `fling` on a sized surface. Don't poke the controller; the test must exercise the real threshold.
- Evidence scripts must FAIL when they can't prove the claim.
- Commit WIP often, and rebase onto `origin/main` before handoff (P-036). Re-resolve the locks rather than hand-merging them.
- Findings start at F-0030.

## Log
- 2026-11-25: Created and dispatched (TL), on top of T-0030 so the work overlaps its verification.
- 2026-11-25: Engineer: built `mc_ds_media`, `mc_ds_cards`, `mc_ds_lists`; moved `McMediaScope` out of `mc_media`; extended `mc_test_utils` with a fixture asset bundle; generated 80 goldens; all gates green (below).

## Outcome
**Handed off** for verification on `fleet/T-0031-ds-lists-media-cards` (built on T-0030 head `63dbaf4`; `origin/main` is not merged yet, merge it after T-0030 lands). Evidence: `documents/evidence/T-0031/engineer/` (gate logs, `coverage.txt`, `AC6_closure.md`, `AC6_negative_control.md`, ten golden PNGs under `goldens/` (copied at their natural size; none exceeds 1200 px)). Finding: [F-0030](../findings/F-0030-widget-test-assets-and-scroll-metrics.md).

### AC to test map
| AC | Tests (name contains the ID) |
|---|---|
| AC1 | `//utility/mc_ds_lists:paged_list_test` and `:paged_grid_test`, group "T-0031-AC1 McPagedList / McPagedGrid load more" (shared in `test/shared_behaviour.dart`): once past 80 % and not before (real `drag`s on a 375x600 surface, then `fling`), asks again after the state changes, never at the end, never while loading, never after a failure, a short list asks once, pull to refresh once. Plus grid columns 2/3/4 by width and the default 3:4 cell |
| AC2 | same files, group "T-0031-AC2 ... states": failure keeps items and Retry calls `onRetry` once; loading-more row; empty view; first-load skeletons; pre-first-load skeletons (no `onLoadMore`); first-load error view with Retry. `//utility/mc_ds_cards:card_test` (skeleton card) |
| AC3 | `//utility/mc_ds_media:image_test`: placeholder then image through a gated bundle; cached image at once; reduced motion; `UnresolvedImageException` (unknown id, unknown set, `https`) shows the fallback with no exception; unknown `ResolvedImage` kind; file load failure; no scope gives a `FlutterError` naming `McMediaScope` |
| AC4 | Goldens: `//utility/mc_ds_media:golden_test` (`image_placeholder`, `image_loaded`, `image_fallback`), `//utility/mc_ds_cards:golden_test` (`card_normal`, `card_long_title`, `card_skeleton`), `//utility/mc_ds_lists:golden_test` (`grid_loading`, `grid_loaded`, `grid_error_footer`, `grid_empty`); each 4 themes x 2 text scales (80 PNGs), real Inter and MaterialIcons, real fixture art. No-overflow: `card_test` "a long title does not overflow" at scales 1, 2, 3, and the goldens at x2 |
| AC5 | `card_test`: button role + title label (+ subtitle as value), no node for the image, tap target >= 44 at scales 1 and 2, tap calls `onTap` once; `image_test`: image excluded from semantics unless it has a label |
| AC6 | `//utility/mc_media:purity_test` ("T-0031-AC6 mc_media has one barrel"), `//utility/mc_ds_media:media_scope_test` (moved, renamed to T-0031-AC6), `tool/checks/T-0031-AC6_closure.sh` ([report](../evidence/T-0031/engineer/AC6_closure.md), [negative control](../evidence/T-0031/engineer/AC6_negative_control.md)), gates below |

### Gates (logs in the evidence directory)
`test //...` 68/68 pass after merging `origin/main` 4f4c8de (`gate-test.log`; the `mc_ds_*` and `mc_media` targets also re-run uncached, `gate-test-uncached.log`); `build --config=lint //...` green; `run //tool/mc_arch_check:bin` OK; `tool/rules_fork.sh check` OK (3 patches); `dart format` clean. Coverage (`bazel coverage`, union of per-target LCOV with `merge_lcov.py`): `mc_ds_media` 64/64 (corrected), `mc_ds_cards` 63/63, `mc_ds_lists` 150/150 (after the fix round), `mc_media` 36/36 (all 100 %).

### Root changes
- Workspace `pubspec.yaml`: added `utility/mc_ds_cards`, `mc_ds_lists`, `mc_ds_media`. `pubspec.lock` and `MODULE.bazel.lock` did not change (no new third-party package).
- `mc_media`: `ResolvedImage` sealed (asset, network); `mc_fixtures_media` `BundledImageResolver` gained `locate()` and `resolve` returns the sealed type; `mc_fixtures_characters` provider contract test and `mc_fixtures_media` tests use `locate()`. `mc_media_scope.dart`, `src/media_scope.dart` and the `mc_media_scope` Bazel library deleted; pubspec lost its `flutter` dependencies (now pure Dart). Its `media_scope_test` moved (git rename) to `mc_ds_media`; `purity_test` now takes `glob(lib/**)` and asserts one barrel.
- `mc_test_utils`: new `fixture_assets.dart` (`McFixtureAssetBundle`, `mcPrecacheFixtureImages`, `mcFixtureAssetsDataLabel`); `mcGoldenApp` gained `bundle:`, `mcGoldenMatrix` gained `assetBundle:` and `precache:`. Both are optional, so existing callers are unchanged.
- `tool/checks/T-0030-AC7_closure.sh`: the positive control is now `//utility/mc_ds_media:mc_ds_media` (the old target is gone). New `tool/checks/T-0031-AC6_closure.sh` wraps it.

### Decisions and deviations for the TL
1. **`McImage` resolves synchronously.** `McImageResolver.resolve` is synchronous (T-0030), so "a resolver that completes later" in AC3 is tested as the image load completing later (a gated asset bundle); the placeholder shows until the first frame.
2. **No fixtures dependency (TL fix round).** `mc_media`'s `ResolvedImage` is now sealed (`ResolvedImage.asset(key, {package})`, `ResolvedImage.network(url)`). `BundledImageResolver.resolve` returns `ResolvedImage.asset(...)` (`locate()` gives the old `BundledImage` value for file checks). `McImage` maps the cases with an exhaustive `switch` (`mcImageProviderFor`). `mc_ds_media` has `mc_fixtures_media` as a dev dependency only. `T-0031-AC6_closure.sh` fails if any production `mc_ds_*` target depends on `mc_fixtures_*` (cquery, with positive and negative controls). New tests: `mc_media:resolved_image_test`.
3. **Grid cell height is a callback** (`cellHeight(cellWidth, textScaler)`), with `McMediaCard.heightFor` as the matching function, so cards with text do not overflow at large text scales. `mc_ds_lists` has no dependency on `mc_ds_cards`, as in plan U31.
4. **No `// ignore:` added. No tests deleted, skipped or weakened.** The three `T-0030-AC6` `McMediaScope` tests moved to `mc_ds_media` and were renamed `T-0031-AC6`; the other `mc_media` tests are untouched.
5. `ScrollMetricsNotification` handling and the once-per-state guard are described in F-0030. `McPagedList` has an `itemBuilder(context, item, index)`; skeletons are builders (`skeletonBuilder`), with a spinner when none is given.
6. Strings (empty, error, "Could not load more.", Retry) are parameters with English defaults until `mc_l10n_core` exists, as in `mc_ds_feedback`.
7. **Goldens were generated once on this machine and re-run by `test //...`; they are byte-checked, not regenerated twice.** The golden target is `macos`-only as in T-0019.

### Follow-ups
- `characters_list` (P1-17) wires `McMediaScope(resolver: BundledImageResolver())` at the app root and uses `McPagedGrid` + `McMediaCard`.
- Carousel, gallery, zoom and the `ds_catalog` screenshots stay out of scope (P1-12 AC4).

## Fix round (Verifier FAIL on AC1 plus code review)
Evidence: `documents/evidence/T-0031/engineer/` (`mutations.sh` and `mutations.log` prove each fix: 13 mutations, each fails the named tests, 0 PROOF-FAILED). Gates after the round: `test //...` 68/68; the `mc_ds_*`, `mc_media` and `mc_paging` targets re-run uncached (16/16); lint, `mc_arch_check`, `rules_fork.sh check` (3 patches), format and both closure checks green. Coverage: `mc_ds_media` 64/64, `mc_ds_cards` 63/63, `mc_ds_lists` 150/150, `mc_media` 36/36, `mc_paging` 117/117.

| # | Item | Fix and proof |
|---|---|---|
| 1 | AC1 threshold not pinned | `asks once past 80 % and not just below it`: a held finger moves in 6 px steps; 0 calls at 77 to 79.5 %, exactly 1 at 81 to 83 %, still 1 up to 97 % (list and grid). A lazy list's extent is estimated, so the test reads the live `maxScrollExtent`, as the widget does. Mutations 0.5, 0.6, 0.75 and 0.95 each fail both suites |
| 2 | Short-page stall | `PagedBody` checks the scroll position in a post-frame callback when the state changes (and at mount). `a short first page asks for the next one` goes through loading to a short page, with and without skeletons, grid and list. Removing the check fails 7 of the 8 (the list with skeletons passes anyway: the skeleton's extent change sends a metrics notification) |
| 3 | Same stall at page 3 | `a list still short after page 2 asks for page 3`: 2, 3, 4 items with no drag, both widgets, both skeleton modes |
| 4 | Default cell height | `cellHeight` is required on `McPagedGrid`. `T-0031-AC4: a card title is not clipped in its cell at scale 1.0 / 2.0` asserts title and subtitle have height > 0 and lie inside their card; the old `width / 0.75` cell fails it at both scales |
| 5 | Purity test regression | restored T-0030's glob of all of `lib/` (BUILD data is `glob(lib/**)`), plus the one-barrel check. A probe `lib/src/probe.dart` with a Flutter import fails it |
| 6 | Button semantics | `button: onTap != null`, `enabled: true` when tappable; `without onTap the card is not a button` |
| 7 | Skeleton semantics | skeleton cards are excluded; the body wraps the skeleton sliver in one `SliverSemantics` labelled `Loading` (`loadingLabel` parameter); `the skeleton announces one Loading` (list, grid) |
| 8 | `on Exception` | `McImage._providerFor` catches `Exception` only; `an Error from a resolver is not swallowed` |
| 9 | Refresh failure copy | neutral copy: `Could not load.` (default of `footerErrorMessage`). The 8 `grid_error_footer` goldens are regenerated; the other 72 are byte-identical |
| 10 | `_requested` latch | cleared when the position goes back below 80 %; `a dropped request is asked again by scrolling` |
| 11 | P-063 | `PagingController` emits `isLoadingMore: false` before rethrowing an `Error`; `T-0031-AC1: an Error from the fetcher settles isLoadingMore` |
| 12 | Traceability | the three moved scope tests are named `T-0030-AC6 T-0031-AC6: ...` |
| 13 | Corrections | `mc_ds_media` coverage corrected; the formatting-only changes to `tool/loc` are reverted to `origin/main` (`tool/loc` on main is not `dart format` clean, so the format gate runs on the other directories) |
| 14 | 44 pt minimum | removed from `McMediaCard` (it could not act inside a cell); `the tap target is at least 44 x 44` asserts the real `InkWell` size at scales 1 and 2 |

Changed goldens: only `utility/mc_ds_lists/test/goldens/grid_error_footer.*` (8 files), because the footer text changed (item 9).
