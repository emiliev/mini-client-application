# T-0059: `mc_ds_charts`: bar, line, donut, radar and timeline painters (U34)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (DS widgets; ADR-0011) |
| Branch | `fleet/T-0059-ds-charts` |
| Created | 2026-11-27 |
| Depends on | T-0019 (DS foundation: `mc_ds_theme`, `mc_ds_layout`, `mc_ds_tokens`) |
| Related | plan 01 U34, the IX+ set (P1-23 `trivia_quiz`: score and round results), F004 `characters_powers` (stat bars, radar), F009 `characters_timeline`, F096 `insights_reading_stats` (DB); T-0044 (DS conventions); F-0043 |

## Goal
Features need charts that look the same on every run, are themed and accessible, and are drawn with `CustomPainter`. No chart package: plan 01 keeps the dependency closure small. IX (`trivia_quiz`) needs bars and a donut first. The rest follow for the bricks.

## Scope
- **In: `utility/mc_ds_charts` (UI)**
  - **`McBarChart`:** vertical or horizontal; one series with optional per-bar colour roles; a value axis with nice ticks; labels; an optional highlighted bar.
  - **`McLineChart`:** 1–3 series; points; an x axis of labels; a y axis with nice ticks.
  - **`McDonutChart`:** segments with colour roles; a centre label; a minimum visible sweep for tiny values (documented).
  - **`McRadarChart`:** 3–8 axes with values 0–1; 1–2 series.
  - **`McTimeline`:** ordered events with a date label, title and marker. Vertical, and scrollable by the caller.
  - **Data model:** immutable value classes, not freezed, to keep the codegen out of the DS. Validation is documented:
    - negative bar values are drawn below the zero line;
    - NaN and infinite values are rejected (`ArgumentError` in debug, skipped plus a report in release);
    - empty data shows the `McEmptyView` style, never a crash.
  - **Shared helpers:**
    - nice-tick computation (1-2-5 steps), a pure function with its own tests;
    - colours only from `mc_ds_theme` roles (series 1–3, positive, negative, neutral), with contrast checked in all 4 themes.
  - **Semantics:** every chart has a summary label passed by the caller (the DS has no l10n). Bars and donut segments expose per-datum semantics ("label: value") so VoiceOver can step through them. Painting is excluded from semantics.
  - **Animation:** optional and off by default. When on, it is driven by an implicit `AnimationController` and can be disabled for tests and goldens.
  - **Goldens:** 4 themes × 2 text scales through `mc_test_utils`, including long German labels, many bars (30), tiny donut segments and an empty state.
- **Out:** interactions (tap-to-select, tooltips on points), stacked or grouped bars, pie labels outside the ring, zoom and pan.

## Acceptance criteria
- **T-0059-AC1:** Goldens for each chart in every state listed above, in 4 themes × 2 scales. There is no overflow at 2×, and a 3× probe test passes.
- **T-0059-AC2: geometry.**
  - Pure-function tests for nice ticks (0, negative ranges, a single value, huge and tiny ranges), bar extents, donut sweeps (they sum to 360°, with the minimum sweep honoured and documented) and radar vertices.
  - Painter tests assert the drawn rects and paths through a recording canvas, not pixels only.
  - Mutations to tick steps, the zero line, the sweep sum and the minimum sweep must be killed.
- **T-0059-AC3: robustness.**
  - Empty data shows the empty state.
  - NaN and infinite values give a debug `ArgumentError`, and in release they are skipped and reported once. Test the release path with an injected flag.
  - All-zero data and a single datum draw without division by zero.
- **T-0059-AC4: semantics and theming.**
  - The summary label and the per-datum labels are present, and VoiceOver order follows the data order.
  - Every series and role colour meets 3:1 contrast against the surface in all 4 themes. This is a test, not a visual judgement.
  - `meetsGuideline` passes.
- **T-0059-AC5: layering and gates.**
  - The package depends only on `mc_ds_theme`, `mc_ds_layout` and `mc_ds_tokens`, plus `mc_ds_feedback` for the empty view if needed (justify it). Extend the layering check.
  - It is registered, and coverage is ≥ 90 %.
  - The 50-run flake check passes on any test with animation.
  - These pass: `test --lockfile_mode=error //...`, lint, `mc_arch_check`, `rules_fork.sh check`, and format on the gated directories only (P-111).
  - Globs use `MC_GENERATED_DART`.

## Log
- 2026-11-27: Created and dispatched (TL).
