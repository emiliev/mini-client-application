# Verification report: T-0031 Design-system lists, media and cards

- **Verifier:** crew: Verifier (a fresh agent; not the implementer)
- **Date:** 2026-11-25
- **Branch / commit verified:** `fleet/T-0031-ds-lists-media-cards` @ **`a9eb91a`** (detached checkout in the Verifier's own worktree). It includes the merge of `origin/main` 4f4c8de (`3f1ae29`).
- **Simulator:** none. This is a package-level task (widget and golden tests only; no app and no e2e).
- **Bazel:** `tool/bazelw --output_base=/tmp/mc-ob-T-0031-verifier …`, a new output base. The shared disk cache is still used, as `.bazelrc` sets. Shut down at the end.
- **Verdict:** **FAIL.** AC2 to AC6 pass. **AC1 fails on test strength.** The implementation fires at 80 % (my probe below), but the mapped test does not pin the 80 % boundary for either widget:
  - Thresholds of 60 % and 75 % pass both suites.
  - A 50 % threshold passes the `McPagedGrid` suite.
  - A 95 % threshold passes the `McPagedList` suite.

  I also found a separate major behaviour defect: a short list stalls after its second page.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| T-0031 packages, uncached | `test --nocache_test_results //utility/mc_ds_media/... //utility/mc_ds_cards/... //utility/mc_ds_lists/... //utility/mc_media/... //utility/mc_test_utils/... //utility/mc_fixtures_media/... //utility/mc_fixtures_characters/...` | **20/20 targets PASSED**. Cases: card 7, cards golden 24, lists golden 32, list 15, grid 16, media golden 24, image 13, media_scope 3. |
| All tests | `test //...` | 68/68 targets pass, exit 0 |
| Lint | `build --config=lint //...` | exit 0 |
| Arch | `run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| Rules fork | `tool/rules_fork.sh check` | `ai_rules_dart: 3 patch(es) apply strictly on pin e7163aab8f91`; `ai_rules_flutter: queue empty, OK` |
| Format | `fvm flutter pub get --enforce-lockfile` then `fvm dart format --output=none --set-exit-if-changed utility tool app` | 284 files, 0 changed. `pubspec.lock` unchanged. |
| T-0031-AC6 closure | `MC_OUTPUT_BASE=… tool/checks/T-0031-AC6_closure.sh` | **PASS**. It re-runs T-0030-AC7 (`mc_paging` 3034 targets / `mc_media` 1135 targets, no Flutter markers; positive control `mc_ds_media` shows `pub_deps__flutter`). It also finds one barrel, no stale `mc_media_scope` references, 9 production `mc_ds_*` libs with no fixtures dependency, and a positive control (`mc_ds_media:image_test` reaches `mc_fixtures_media`). |
| AC6 negative control (mine) | Add `"//utility/mc_fixtures_media"` to the `mc_ds_media` `flutter_library` deps only | **FAIL T-0031-AC6**, exit 1: `mc_ds_media -> //utility/mc_fixtures_media:…` and, transitively, `mc_ds_cards -> …`. Reverted. Note: my first attempt added it to `_DEPS`. That duplicates the label in `_TEST_DEPS`, so the BUILD file fails to load, and the script then fails for the wrong reason ("query returned nothing"). The second attempt is the valid control. |
| Coverage (my parser, `verifier/cov.py`) | `coverage --nocache_test_results` over the 4 packages, then the union of `DA` lines per package across every `coverage.dat`. Both SF forms are handled (`package:` for flutter_test, workspace paths for dart_test). Lib files absent from LCOV are listed. | `mc_ds_media` 63/63, `mc_ds_cards` 63/63, `mc_ds_lists` 131/131, `mc_media` 36/36: **100 % each**. The only files absent from LCOV are the export-only barrels. (The Outcome says `mc_ds_media` 62/62; `coverage.txt` and I get 63/63. Nit.) |
| Golden determinism | `run //utility/{mc_ds_media,mc_ds_cards,mc_ds_lists}:golden_test -- --update-goldens`, twice, from the new output base | 24 + 24 + 32 = **80 written per run**. `git status` is clean after both runs, so the goldens are byte-identical to the committed ones. |
| Existing goldens (backward compatibility) | `test --nocache_test_results` for `mc_ds_theme`, `mc_ds_layout`, `mc_ds_buttons`, `mc_ds_feedback` and `mc_test_utils:golden_test` | 5/5 PASSED. No existing PNG is modified (`git diff --name-status origin/main HEAD`: every PNG is `A`). |
| L4 E2E | n/a | No app is in scope. |

## Acceptance criteria
| AC | Mapped test(s) | Does the test really assert the AC? | Result |
|---|---|---|---|
| T-0031-AC1 | `paged_list_test` / `paged_grid_test`, group `T-0031-AC1 … load more` (`test/shared_behaviour.dart`) | **Partly.** Real `tester.drag` / `fling` on a 375x600 surface; no controller pokes. Latch, end, in-flight, failure, re-arm-on-state-change and short-list behaviour are each pinned (mutations M3 to M8 go red). **The 80 % boundary is not pinned.** `asks once past 80 % and not before` checks for nothing at "about 50 %" (`max*0.5`, `shared_behaviour.dart:60`) and for one call at "about 95 %" (`+max*0.45`, `:66`). Because of the drag slop, the grid's first stop lands just under 50 % and the list's second stop lands at or above 95 %. Results: M1 (50 %) is red for the list but **green for the grid**. M2 (95 %) is red for the grid but **green for the list**. M1b (60 %) and M1c (75 %) are **green for both**. The AC says "when scrolled to 80 % … Prove the same for `McPagedList`", and neither widget's test proves it. The implementation itself is correct: my step-drag probe fires at 0.797 → 0.819 (grid) and 0.796 → 0.810 (list) of the live `maxScrollExtent`. | **FAIL** (test gap; Issue 1) |
| T-0031-AC2 | group `T-0031-AC2 … states` in both suites; `card_test` skeleton | Yes. A failure keeps `item 0` / `item 2` visible and shows "Could not load more." and Retry; a tap gives `retry == 1`. Also covered: the empty view, first-load skeletons (`Key('skeleton')`), pre-first-load skeletons with no `onLoadMore`, and the first-load error view. Mutations M9 to M13 each go red in both suites. | **PASS** |
| T-0031-AC3 | `image_test` group `T-0031-AC3` | Yes. A gated `McFixtureAssetBundle` shows the placeholder, then the gate completes, a bounded real-clock wait runs, and `loadedKey` appears with `fileLoads == 1`. Unknown id, unknown set and `https` show the fallback with no exception. A throwing resolver shows the fallback. A `failingKeys` load shows the fallback. No scope gives a `FlutterError` that contains `McMediaScope`. `mcImageProviderFor` maps asset to `AssetImage` and network to `NetworkImage`. My probes: a truly missing key (`ResolvedImage.asset('assets/characters/does_not_exist.png', package: 'mc_fixtures_media')`) shows the fallback and nothing throws; a network resolver makes `McImage` build `Image(image: NetworkImage('https://x.test/a.png'))`, which falls back once the load fails. Mutations M14 to M18 each go red. The TL decision "resolve is synchronous; 'later' is the load" matches the code (`mc_image.dart:47`, `_providerFor`). | **PASS** |
| T-0031-AC4 | `golden_test` in `mc_ds_media` (placeholder, loaded, fallback), `mc_ds_cards` (normal, long title, skeleton) and `mc_ds_lists` (loading, loaded, error footer, empty): 80 PNGs = 10 states × 4 themes × 2 scales. Also `card_test` "long title does not overflow" at 1, 2 and 3. | Yes. Goldens are deterministic (above), and `mcGoldenMatrix` asserts `takeException() == null`, so a `RenderFlex` overflow fails the test. I viewed 9 PNGs: real Inter (proportional, weights 500/400) and MaterialIcons glyphs (`image_not_supported_outlined`, `inbox`). The fixture art matches `mc_fixtures_media/assets/characters/*.png` (gradient + silhouette). There are no overflow stripes at x2: long titles ellipsize at 2 lines and the subtitle at 1. HC themes are visibly distinct (black outlines and darker red on white vs. grey on `#F6F6F6`; pure black in HC dark). No two variants of one state are byte-identical, except `McImage` x1 and x2, which have no text. **Mutations:** dark `outline` 1 unit (`0xFF7C7C88` → `…89`) fails exactly the 12 dark goldens that draw an outline (cards 6, lists 6; media 0, which does not use it). Card `_textPadding` `sm` → `xs` fails 24/24 card goldens and 24/32 list goldens (all but `grid_empty`), for example `card_normal.light.x1.png: Pixel test failed, 2.36%, 11328px diff`. | **PASS** |
| T-0031-AC5 | `card_test` (button + label + value, image adds no node, tap target ≥ 44 at 1x and 2x, tap once); `image_test` semantics group | Yes for the role, label and value, and for image exclusion. Mutations M19 to M22 go red. **Guidelines (mine; the tests don't run them):** the card (2 cards × 4 themes × 2 scales) and the grid (error footer with items, first-load error, empty; × 4 themes × 2 scales) pass `iOSTapTargetGuideline`, `androidTapTargetGuideline`, `labeledTapTargetGuideline` and `textContrastGuideline`: 8/8 and 24/24. Card node: `actions: [tap], flags: [isButton], label: "Nova", value: "Hero"`, rect 160x272 (x1) / 160x325 (x2). Mutation M23 (remove the `ConstrainedBox` 44 minimum) stays **green**: the box can never take effect inside a grid cell, so it is untested and inert (Issue 4, nit). | **PASS** |
| T-0031-AC6 | `mc_media:purity_test` (`T-0031-AC6 … one barrel`), `mc_ds_media:media_scope_test` (3 moved tests), `tool/checks/T-0031-AC6_closure.sh`, gates | Yes. `mc_media/pubspec.yaml` has no `flutter`/`flutter_test` (dev: `mc_analysis`, `test` only). There is one top-level barrel. `McMediaScope` is in `mc_ds_media/lib/src/mc_media_scope.dart` (git rename R085). The 3 tests moved with R087 and only their imports and AC names changed; every assertion is identical. Workspace `pubspec.yaml` lists the 3 packages and `pub get --enforce-lockfile` passes. Arch, lint, `rules_fork` and format are green. Coverage is 100 %. The closure check and my negative control behave as expected. Regression (Issue 3, minor): the T-0030-AC7 purity test is weaker than it was on `main`. | **PASS** |

## AC1 probes (with real drags and flings; file `verifier/lists_probe_test.dart`)
| Probe | Result |
|---|---|
| Boundary: 40 px drags, recording `pixels / maxScrollExtent` | grid: no call at 0.797, first call at 0.819 (max 956). list: no call at 0.796, first call at 0.810. The list's `maxScrollExtent` is a `SliverList` estimate (1641.6 at the start, 1568 when it fires); the threshold uses the live value, which is correct. **OK** |
| Short list (2 items, `maxScrollExtent == 0`) | Asks exactly once, and twenty more frames plus overscroll drags up and down do not change that: no loop. **OK** |
| Short list, page 2 arrives and the list is still short (2 → loading → 4 items) | **Stalls:** `n` stays 1 for both widgets. The state changed, so `_requested` resets, but `ScrollMetricsNotification` only fires when metrics change, and `maxScrollExtent` is still 0. Nothing asks for page 3 until the user drags, which gives `n = 2`. See Issue 2. |
| Fast fling past the end (`fling -20000 @ 20000`, twice) | `pixels == maxScrollExtent`, `n == 1`. **OK** |
| Latch | A new but equal `PagedState` instance does not re-arm, even with further drags (`n == 1`). In flight: `n == 1`. Page 2 (40 items): no call below 80 % of the new extent; the next fling past the threshold gives `n == 2`. **OK** |
| Rotation / resize (375x600 at 70 %, then 812x375, then back) | Grid: 4 columns, 70 % becomes 92 % of the new extent, the metrics notification fires once (`n == 1`), and rotating back does not fire again. List: 70 % becomes 64 %, `n == 0`, and still `n == 0` after rotating back. No exceptions. **OK** |

## Mutations (each applied with `verifier/mutate.sh`, run uncached, then restored from a backup; tree clean afterwards)
| # | File | Mutation | Red tests |
|---|---|---|---|
| M1 | `paged_body.dart` | threshold 0.8 → 0.5 | list `asks once past 80 %…` only. **Grid green.** |
| M1b / M1c | same | 0.8 → 0.6 / 0.75 | **none** |
| M2 | same | 0.8 → 0.95 | grid `asks once past 80 %…` only. **List green.** |
| M3 / M3b | same | drop `!_requested &&` / never set `_requested = true` | both suites: `asks once…`, `asks again after the state changed` |
| M4 | same | drop `!s.hasReachedEnd` | both: `never asks at the end` |
| M5 | same | drop `!s.isLoadingMore` | both: `never asks while a load is in flight` |
| M6 | same | drop `s.failure == null` | both: `never asks after a failure`, AC2 `failure keeps the items…` |
| M7 | same | `_onMetrics` no longer calls `_maybeRequest` | both: `a list shorter than the viewport asks once` |
| M8 | same | no latch reset in `didUpdateWidget` | both: `asks again after the state changed` |
| M9 | same | any failure shows the full error view (items hidden) | both: AC2 `failure keeps the items…` |
| M10 | same | Retry calls `onRetry` twice | both: AC2 `failure keeps the items…` |
| M11 | same | empty view condition broken | both: AC2 `empty settled state…` |
| M12 | same | ignore `skeletonSliver` | both: AC2 `first load shows the skeletons`, `state before the first load…` |
| M13 | same | footer never shows the inline error | both: AC2 `failure keeps the items…` |
| M14 | `mc_image.dart` | frame always "ready" (no placeholder) | `placeholder first, then the resolved bundled image` |
| M15 | same | catch only `UnsupportedError` | `UnresolvedImageException shows the fallback…`, `a resolver that throws…` |
| M16 | `mc_media_scope.dart` | error message without the name | `image_test` no-scope test; `media_scope_test` `without a scope throws FlutterError` |
| M17 | `image_provider_for.dart` | network → `AssetImage` | `each ResolvedImage case maps to its ImageProvider` |
| M18 | `mc_image.dart` | `errorBuilder` shows the placeholder | `a file that fails to load shows the fallback` |
| M19 | same | unlabelled image gets a semantics label | AC5 `an image without a label is not in semantics` |
| M20 / M21 / M22 | `mc_media_card.dart` | drop `button: true` / label ↔ subtitle / drop `ExcludeSemantics` | AC5 `button labelled with its title` (M20, M21); `image adds no semantics node` (M22) |
| M23 | same | `ConstrainedBox` min 44 → 0 | **none** (Issue 4) |
| G1 / G2 | `colors.dart` / `mc_media_card.dart` | dark `outline` +1 / `_textPadding` sm → xs | 12 dark goldens / 48 goldens (see AC4) |

## Test-integrity audit
- **Tests deleted, skipped or weakened:**
  - The 3 `McMediaScope` tests moved (R087) with identical assertions. The `mc_fixtures_*` tests now call `locate()` in place of `resolve()` with the same assertions, and `media_contract_test` gained an assertion.
  - **One weakening is not disclosed:** the merge `3f1ae29` resolved the `utility/mc_media/test/purity_test.dart` conflict in favour of the branch. That drops T-0030's fix-round version, which listed `lib/` recursively, and restores a hard-coded three-file list (`purity_test.dart:25-29`). The library's `srcs` are hard-coded too (`mc_media/BUILD.bazel:12-16`). This undoes the fix for T-0030 Verifier item 7. My probe, a new `lib/src/zz_verifier_probe.dart` importing `package:flutter/widgets.dart`, makes `purity_test` **PASS** (under T-0030 it FAILED). Issue 3.
- **Lint suppressions added:** none. `git diff origin/main HEAD` has no `+` lines with `// ignore`, `ignore_for_file` or `skip:`.
- **Golden files updated:** none existing. 80 new goldens.
- **Traceability:** every AC has tests with the ID in the name. Name occurrences: AC1 11, AC2 9, AC3 13, AC4 13, AC5 7, AC6 8.
- **`mc_test_utils` changes are backward-compatible:**
  - `mcGoldenApp(bundle:)` returns the identical `MaterialApp` when `bundle == null`.
  - `mcGoldenMatrix(assetBundle:, precache:)` does nothing new when `precache` is empty.
  - The 5 pre-existing golden targets pass uncached.
- **Diff review vs `origin/main`:**
  - Unrelated change: `tool/loc/**` (4 files, from WIP commit `a0e3257`). I re-ran `dart format` over the `origin/main` versions and they are **byte-identical** to the branch, so this is formatting only. It is not mentioned in the Outcome (Issue 6, nit).
  - The merge `3f1ae29` brings only `origin/main` content. `--remerge-diff` shows 3 conflict resolutions: the task file, `mc_media/BUILD.bazel` and `purity_test.dart` (Issue 3).
  - `pubspec.lock` and `MODULE.bazel.lock` are unchanged by the branch.
- **TL decisions, checked in the code:**
  - `resolve` is synchronous.
  - `ResolvedImage` is sealed and pure (`mc_media/lib/src/image_resolver.dart`), and `mcImageProviderFor` switches over it exhaustively.
  - No production `mc_ds_*` depends on `mc_fixtures_*` (cquery).
  - `McPagedGrid.cellHeight(cellWidth, textScaler)` exists, and `mc_ds_lists` depends on `mc_ds_cards` only as a dev dependency.
  - The `ScrollMetricsNotification` listener exists (`paged_body.dart:95,135`).
  - `McMediaScope` is in `mc_ds_media`.

## Visual acceptance
| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| grid loaded, HC dark, x2 | `verifier/grid_loaded.highContrastDark.x2.png` (downscaled 750x1280 → 703x1200) | 2 columns of cards with real fixture art. White Inter titles wrap to 2 lines and ellipsize ("Captain Pell of th…"); light-grey "Hero"; white outlines on black. | yes |
| grid error footer, light, x2 | `verifier/grid_error_footer.light.x2.png` (703x1200) | 2 cards stay visible. Below them, red "Could not load more." wraps to 2 lines beside a red "Retry" text button. | yes |
| long-title card, light, x2 | `verifier/card_long_title.light.x2.png` (750x800) | Art, then "Wiimm the / Wandere…" (2 lines, ellipsized), then "A subtitle t…". No overflow stripe. | yes |
| image fallback, HC, x2 | `verifier/image_fallback.highContrast.x2.png` (750x560) | Light-grey `#EDEDED` box with a black `image_not_supported` icon. | yes |
| also viewed, not copied | `grid_loading.dark.x1`, `grid_empty.highContrastDark.x2`, `image_placeholder.dark.x1`, `grid_error_footer.highContrast.x1`, fixture `005.png` | Skeleton cards (grey blocks and bars, outlined); inbox icon, "Nothing here yet" and the custom empty message; a flat `surfaceVariant` box; HC footer with black outlines and dark red; the source art matches the goldens. | yes |

## Issues found
1. **(Blocker for AC1; test gap) The load-more test does not pin the 80 % threshold for either widget.** In `utility/mc_ds_lists/test/shared_behaviour.dart:52-75`, the "not before" point is `drag(-max*0.5)` (`:60`) and the "past" point is a further `drag(-max*0.45)` (`:66`). Thresholds of 0.6 and 0.75 pass both suites, 0.5 passes the grid suite and 0.95 passes the list suite (table above). The test name claims "past 80 % and not before". **Repro:** set `mcPagedLoadMoreThreshold = 0.75` in `lib/src/paged_body.dart:10` and run `test //utility/mc_ds_lists:paged_list_test //utility/mc_ds_lists:paged_grid_test`: both pass. **Suggested fix** (the code is already right): drag to just below 80 %, assert 0 calls, then a little past it and assert 1. Take the ratios from the live `position.pixels / position.maxScrollExtent` (the list's extent is an estimate until laid out; F-0030 could note this), or step-drag as in `verifier/lists_probe_test.dart` "boundary". Then confirm that 0.75 and 0.85 both turn each suite red.
2. **(Major, behaviour; not part of an AC's wording) A list or grid that is still shorter than the viewport after a page arrives never asks for the next page on its own.** Mechanism (`lib/src/paged_body.dart:59-64, 95-99`):
   - `_requested` is cleared in `didUpdateWidget`.
   - Only a `ScrollNotification` or a `ScrollMetricsNotification` can trigger a request.
   - With `maxScrollExtent` still 0 and the viewport unchanged, the metrics are equal, so Flutter dispatches no `ScrollMetricsNotification`.

   **Repro** (`verifier/lists_probe_test.dart` "short list"): states `pagedState(2)`, then `(2, isLoadingMore)`, then `pagedState(4)` on a 375x600 surface. `onLoadMore` count stays 1. A user drag up then gives 2. In the app this means a small page size, a tall iPad viewport or sparse search results leave the user on a half-empty screen with a footer gap and no spinner. **Suggested fix:** when `didUpdateWidget` sees a new state, add a post-frame callback that runs `_maybeRequest(position)` with the scrollable's current metrics (`controller` or `Scrollable.maybeOf`), and add a test that asks twice across two short pages.
3. **(Minor, integrity) The merge `3f1ae29` silently weakened the T-0030-AC7 purity test.** `utility/mc_media/test/purity_test.dart:25-29` hard-codes 3 files again, and `utility/mc_media/BUILD.bazel:12-16` hard-codes `srcs`. T-0030's fix round (on `main`) had made it list every file under `lib/`. Probe: a new Flutter-importing file under `lib/src/` passes `purity_test`. The handoff says "No tests deleted, skipped or weakened". The practical risk is low: a file outside `srcs` is not in the library, and adding it to `srcs` would fail the kernel compile and the closure check. Still, it reverts a Verifier-requested fix. **Fix:** restore the recursive listing (the 3-file `srcs` list can stay, or go back to a `glob`).
4. **(Nit) The `ConstrainedBox(minWidth/minHeight: 44)` in `McMediaCard` (`utility/mc_ds_cards/lib/src/mc_media_card.dart:120-124`) is inert and untested.** A grid cell is always far larger, and under tight constraints the box cannot enlarge anything. M23 (min 0) leaves every test green. The ≥ 44 pt claim holds through `heightFor` and the cell size, and my tap-target guidelines pass. Either test a small card or drop the box.
5. **(Nit) Possible improvements, with no AC impact:**
   - `McMediaCard` announces `isButton` even when `onTap` is null, with no enabled state (`mc_media_card.dart:137`).
   - `McImage._providerFor` catches `on Object` (`utility/mc_ds_media/lib/src/mc_image.dart:86`). That also hides programming errors in a resolver as a fallback picture; catching `Exception` (`UnresolvedImageException`, `FormatException`) and letting `Error`s through would surface wiring bugs.
6. **(Nit, hygiene)**
   - `tool/loc/**` was re-formatted in the WIP commit `a0e3257`. It is formatting only (verified byte-identical to `dart format` of `origin/main`) but is not mentioned in the Outcome. The `origin/main` versions were not format-clean.
   - The Outcome says `mc_ds_media` coverage is 62/62, but it is 63/63.
   - Under `bazel coverage`, `mc_media:purity_test` takes about 103 s. This is the known coverage-mode quirk from the T-0030 report, item 8.

## Notes for the Tech Lead
- **Re-verification scope:**
  - Issue 1 needs only test changes in `utility/mc_ds_lists/test/shared_behaviour.dart`.
  - Then re-run the threshold mutations 0.5, 0.75, 0.85 and 0.95 against **each** suite. Each must turn that suite red. That means the "before" probe lands in [0.75, 0.8) and the "past" probe in [0.8, 0.85).
  - Issue 2, if fixed in the same round, adds one `paged_body.dart` change and a test. Everything else in this report can be carried forward.
- Issue 2 matters for T-0032 (`characters_list` EX-AC6) only if a page doesn't fill the viewport. With limit 20 on an iPhone it does fill, so T-0032 isn't blocked in practice. Still, the DS component should not stall.
- **Evidence:**
  - `documents/evidence/T-0031/verifier/`: 4 PNGs; the probe sources `lists_probe_test.dart`, `cards_a11y_test.dart` and `media_probe_test.dart`; `mutate.sh`; `cov.py`.
  - My scratch tests and temporary BUILD targets were removed from the packages.
  - Every mutation was restored from a backup, and `git status` was clean apart from this evidence before the commit.
