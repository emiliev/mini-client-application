# T-0031: Design-system lists, media and cards for LD (P1-12 subset: `mc_ds_media`, `mc_ds_lists`, `mc_ds_cards`)

| Field | Value |
|---|---|
| Status | Ready (dispatch after T-0030 merges) |
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
- 2026-11-25: Created (TL); dispatch after T-0030 merges.
