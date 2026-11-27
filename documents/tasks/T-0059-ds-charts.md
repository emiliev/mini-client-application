# T-0059: `mc_ds_charts`: bar, line, donut, radar and timeline painters (U34)

| Field | Value |
|---|---|
| Status | In Verification (Engineer done) |
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
- 2026-11-27: Engineer (Sonnet) built `utility/mc_ds_charts`: `McBarChart`, `McLineChart`, `McDonutChart`, `McRadarChart`, `McTimeline`, the pure geometry in `chart_math.dart`, `McChartRole` and `McChartValidation`. Added the series colour roles to `McPalette` (`mc_ds_tokens`). 236 non-golden tests, 232 goldens, a layering check, a gates check and an 84-mutant script. First mutation run: 78 killed, 5 survived, 1 broken; the survivors were fixed with tests (a tick-rounding case, an edge label that would leave the canvas, the donut track while drawing in, palette equality for `series3`, and the debug path thrown rather than reported) and the broken mutant was rewritten. Second run: 84 of 84 killed. Handed off.

## Outcome
**Status:** Done, ready for verification. Branch `fleet/T-0059-ds-charts`. Finding: [F-0059](../findings/F-0059-ds-charts.md). Evidence: `documents/evidence/T-0059/engineer/`.

### Public API
Barrel `package:mc_ds_charts/mc_ds_charts.dart`. Every chart takes a localised `semanticLabel` (summary) and `emptyMessage` (plus optional `emptyTitle`), because the DS has no l10n; optional `valueFormatter` (default `mcFormatValue`); `animate` (default false).
- `McBarChart({data: List<McBarDatum>, orientation = Axis.vertical, highlightIndex, height = 240})`; `McBarDatum({label, value, role})`.
- `McLineChart({xLabels, series: List<McLineSeries> (1 to 3), height = 240})`; `McLineSeries({label, values, role})`; NaN is a gap.
- `McDonutChart({data: List<McDonutSegment>, centerLabel, centerCaption, size = 200, minSweepDegrees = 4, showLegend = true})`.
- `McRadarChart({axes (3 to 8), series: List<McRadarSeries> (1 or 2), height = 280})`; values 0 to 1, clamped.
- `McTimeline({events: List<McTimelineEvent>})`; `McTimelineEvent({date, title, description, role})`. Not scrollable: the caller scrolls.
- `McChartRole` (`series1..3`, `positive`, `negative`, `neutral`, `resolve(palette)`), `McChartValidation` (release flag and reporter, `@visibleForTesting`), and the pure helpers `mcNiceTicks`, `mcLayoutBars`, `mcDonutSweeps`, `mcDonutArcs`, `mcRadarVertex`, `mcFormatTick`, `mcFormatValue`.
- Painters (`McBarPainter`, `McDonutPainter`, `McLinePainter`, `McRadarPainter`, `McTimelineRailPainter`) are public so tests can drive them with a recording canvas.

### AC to evidence
| AC | Evidence |
|---|---|
| AC1 | `test/golden_test.dart`: 29 states x 4 themes x 2 scales = 232 goldens (bar: vertical, roles and highlight, negative, long German labels, 30 bars, horizontal, horizontal German with negatives, single, all zero, empty, empty German; donut: basic, tiny segments, German, single, all zero, empty; line: one series, three series, negative and German, single point, empty; radar: one series, two series on eight axes, three axes German, empty; timeline: basic, German single, empty). All looked at; charts sit on `surface`. No overflow: `charts_test.dart` "T-0059-AC1 <chart> at 1x / 2x / 3x has no overflow" for 7 chart variants with long German labels, "a 3x probe on a narrow column" (280 pt), an unbounded width (320 pt fallback), a narrow parent for the donut |
| AC2 | `test/geometry_test.dart`: nice ticks (zero, negative, single value, huge 1e12 and 1e300, tiny 3e-9, noise, bad bounds), bar extents (positive, negative, negative-only, horizontal, progress, 30 bars), donut sweeps (sum to 360 degrees, minimum sweep, cascade, equal-share fallback, zero stays zero, single, 200 random inputs), radar vertices (3 to 8 axes). `test/painter_test.dart` with a recording canvas: drawn rects, zero line (position, width, drawn over the bars), grid lines, highlight, arcs and gaps, track ring, markers and paths, radar rings, spokes and polygon, timeline rail. Mutation script: tick steps, zero line, sweep sum and minimum sweep, radar vertices all killed (84 of 84) |
| AC3 | `charts_test.dart`: empty state for every chart (8 cases); NaN, +/-infinity and negative donut values throw `ArgumentError` in debug (4 charts x 3 values + 1); release path through the injected flag: skipped or drawn as a gap or 0, reported once per data change, not again on rebuild; unsupported shapes (4 line series, 2 or 9 radar axes, 3 radar series, wrong lengths); all-zero, single datum, constant line, single point, single timeline event draw without a non-finite number |
| AC4 | `charts_test.dart`: summary label then per-datum nodes in data order for every chart (traversal order, also when data order differs from visual order, horizontal, 30 bars); legend and centre text hidden; `meetsGuideline` text contrast, labelled tap target and iOS tap target for 8 states in all 4 themes (32 tests). `geometry_test.dart`: every series and role colour at least 3:1 on `surface` in the 4 themes, roles map to the palette fields, series colours differ. `charts_test.dart` re-checks the colours actually drawn in the 4 themes |
| AC5 | `tool/checks/T-0059-AC5_layering.sh` ([report](../evidence/T-0059/engineer/ac5-layering.md)): closure of the library holds only theme, layout, tokens, feedback and buttons (via feedback); sources, pubspec and BUILD name only allowed packages; no lower DS package names the charts; positive controls; 19 negative controls. `tool/checks/T-0059-AC5_gates.sh` ([report](../evidence/T-0059/engineer/ac5-gates.md)): `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format (gated directories only), l10n_check, provenance, fixtures closure, layering, no other package's goldens changed, no suppressions; **coverage `mc_ds_charts` 99.1 % (982/991)**. Flake: 50 runs of all 4 test targets, 0 failures ([log](../evidence/T-0059/engineer/flake-50.log)) |

Mutations ([script](../evidence/T-0059/engineer/mutations.sh), [table](../evidence/T-0059/engineer/mutants.py), [log](../evidence/T-0059/engineer/mutations.log)): **84 of 84 killed**, 0 survived, 0 broken. The script refuses a dirty tree, sets its restore trap before the first edit, counts `Build did NOT complete` as broken and only `FAILED in` as killed.

### Decisions (no ADR needed; all cheap to reverse)
- **Colour roles:** `McPalette` gets `series1`, `series2`, `series3` (new colours; series1 equals `primary`, series 2 is blue, series 3 teal, each at least 3:1 on `surface` in all 4 themes) and the getters `positive` (= `success`), `negative` (= `error`), `neutral` (= `outline`). No existing colour or pixel changed: the gates diff every other package's goldens against `origin/main`. This is the one edit outside the package besides the workspace list (`mc_ds_tokens/lib/src/colors.dart`).
- **`mc_ds_feedback` dependency:** for `McEmptyView` only (the brief asks for the empty-view style). It brings `mc_ds_buttons` into the closure; the layering check allows exactly that.
- **No chart package, no freezed:** plain immutable classes with value equality.
- **Painters, not widgets, for labels:** axis and category labels are `TextPainter`s inside the painter, scaled with the text scale and ellipsised; long labels thin out by stride, and labels that would be cut off are skipped. The timeline uses widgets for the text and one painter for the rail.
- **Validation extras beyond the brief:** a negative donut value is rejected like NaN; a line series longer than its labels, more than 3 line series, more than 2 radar series, 3 to 8 radar axes and a radar series of the wrong length throw in debug and degrade in release.
- **Radar non-finite values** are drawn as 0 (not skipped), because dropping a value would shift the axes.
- **Bar value labels, tooltips, stacked bars:** not built (out of scope).

### Test integrity
New package; nothing deleted, skipped or weakened; no `// ignore:`; no existing golden changed. Edits outside the package: the workspace `pubspec.yaml` list (`utility/mc_ds_charts`), `utility/mc_ds_tokens/lib/src/colors.dart` (the palette roles), and two new checks in `tool/checks/`. `mc_ds_theme` needed no change.

### Notes
- `charts_test`, `painter_test` and `geometry_test` run under plain `fvm flutter test` (3 s); see F-0059 fact 5.
- Follow-ups: restrict package visibility with the P3-06 package_group (as for every DS package); a `McBarChart` value-label option and tap-to-select if a brick needs them.
