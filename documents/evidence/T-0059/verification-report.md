# T-0059 Verification report

- **Verifier:** fresh agent (Sonnet tier, ADR-0011), own worktree, own Bazel output base `/tmp/mc-ob-T-0059-verifier` (shut down afterwards)
- **Commit verified:** `eb9879a` (`fleet/T-0059-ds-charts` after the review round)
- **Verdict: PASS** (no blocking defects; 2 non-blocking test gaps and 2 cosmetic notes below)

Evidence is in `documents/evidence/T-0059/verifier/`.

## Summary per AC

| AC | Result | How it was checked |
|---|---|---|
| AC1 goldens | PASS | 14 goldens viewed by eye (list below). 232 PNGs are new, all under `utility/mc_ds_charts`; the diff of `origin/main...eb9879a` for PNGs outside the package is empty (0 files), and the palette change moved no existing golden. 12 changed line goldens: viewed 3 (`line_three_series.light.x1`, `line_three_series.dark.x2`, `line_one_series.highContrastDark.x2`); the zero line is now drawn on the baseline as the review item describes. No-overflow and 3x tests exist (9 `T-0059-AC1` tests in `charts_test.dart`, 2 in `golden_test.dart`). |
| AC2 geometry | PASS | Own probe (`probe_test.dart.txt`, output `probe-output.log`), all asserts green. Painter tests use the recording canvas (59 + 43 `AC2` tests). Mutations in ticks, zero line, sweep sum and minimum sweep killed (below). |
| AC3 robustness | PASS | Own probe: release path via the injected flag, debug throws, donut colour stability, neighbours, 4th-series empty view (details below). |
| AC4 semantics, theming | PASS | Own probe plus the `meetsGuideline` tests (text contrast, labelled tap target, iOS tap target in all 4 themes). |
| AC5 layering, gates | PASS | Gates script, layering script with controls, `test --lockfile_mode=error //...`, 50-run flake check, own coverage parser. |

## AC1: goldens viewed
`bar_thirty.light.x2`, `bar_german_labels.dark.x2`, `bar_horizontal_german_negative.highContrast.x2`, `bar_roles_highlight.light.x1`, `bar_all_zero.light.x1`, `donut_tiny_segments.highContrast.x1`, `donut_german.dark.x2`, `donut_empty.light.x1`, `line_three_series.light.x1`, `line_three_series.dark.x2`, `line_one_series.highContrastDark.x2`, `radar_two_series_eight_axes.light.x1`, `radar_three_axes_german.dark.x2`, `timeline_basic.highContrastDark.x2`.

Observations: 30 bars at 2x thin the labels to every 9th ("Tag 1, Tag 10, Tag 19") with no overlap and nothing cut off. German labels are ellipsised cleanly ("Durchsch...", "Donauda..."). The tiny donut segments (1000, 2, 1, 0.5) are all visible, with a legend that carries the exact numbers (sweep floor 4 degrees). The empty states show `McEmptyView`. The zero line sits on the axis in every state. Series are told apart by marker shape as well as colour. Nothing is clipped.

Cosmetic notes (not defects): `bar_horizontal_german_negative` leaves a large blank area below the chart (the golden surface is taller than the content). In `radar_three_axes_german`, the labels for a 3-axis radar are ellipsised even though there is room beside them.

## AC2: geometry probe results (actual values)
- Nice ticks: `0..0` gives `0..1` step 0.5 (3 ticks). `-7..3` gives `-10..5` step 5 (4 ticks). `0.001..0.004` gives `0.001..0.004` step 0.001 (4 ticks). `1e9..3e9` gives `1e9..3e9` step 5e8 (5 ticks). All cover the data, with a positive step.
- Donut sweeps: sum is 360.0 degrees (within 1e-9 rad) for `[1000,2,1,0.5]`, `[1,1,1]`, `[5]`, `[1e-9,1,1e9]`, 90 equal values and a 40-value case. All zero gives 0. The minimum 4.0 degrees is honoured. For 90 values (90 x 4 = 360, so the minimum does not fit) the equal-share fallback applies and the sum is still 360. The last arc ends at start + 2 pi.
- Radar: for 3, 5 and 8 axes, vertices match the closed-form angle. Axis 0 points straight up (100, 50). A value of 0 is the centre, and a value of 7 is clamped to the radius. n=3: (100,50), (143.3,125), (56.7,125).
- Bar extents, vertical and horizontal: `[5,-3,0]` has zero y at 60, with the +5 bar from 10 to 60, the -3 bar from 60 to 90 and a zero-height bar at 60. `[-2,-8]` has zero at the top (0). `[0,0]` has zero at the bottom (100) with zero-height bars. `[4,10]` has zero at the bottom. Positive bars end on the zero line, negative bars start on it, and all rects stay inside the plot.
- Zero line (line chart): drawn (one heavier horizontal line, 1.5 pt) for `0..10`, `-10..0` and all-zero. Not drawn for `2..6`, where 0 is off the axis.

## AC3: robustness probe results
- Release `[A, B:NaN, C, D]` with `highlightIndex: 2`: the painter data is `[A, C, D]`, `highlightIndex` is 1 (C), one report, and exactly one highlight outline is drawn, centred on the C bar.
- Donut with the colour roles `[series1, default, default, default]`: dropping a NaN datum keeps the other colours (the dropped chart's segments 2 and 3 have the colours of the full chart's segments 3 and 4).
- A donut with 5, 6 and 9 default segments gives different colours to every adjacent pair, including the last and the first (checked on the colours actually drawn, and on `McChartRole.resolveAll`).
- 4 line series where only the 4th has data, in release: shows the empty message.
- Debug: a NaN bar throws `ArgumentError` (captured among the build errors).
- A radar with 5 axes and 3 values throws in debug (a documented validation) and reads all 5 axes in release.

## AC4: semantics and theming
- Semantics order (simulated VoiceOver traversal): `[SUMMARY, Mon: 0, Tue: 0, Wed: 2]`. `-0.0` and `-0.001` read "0", never "-0".
- Radar with 5 axes and 3 values reads `[RAD, S: a 0.5, b 0.2, c 0.9, d 0, e 0]`.
- Contrast against `surface`, computed by my own code (`probe-output.log`) and 4 re-derived by hand with an independent Python implementation of the WCAG formula:
  - light `series1` B3131B on FFFFFF: 6.94
  - light `neutral` 8E8E98 on FFFFFF: 3.24 (the tightest role of all; the finding documents that it is 2.9 on the light `background`, and charts sit on `surface`)
  - dark `series1` FF6B70 on 1A1A1E: 6.27
  - highContrast `series3` 00574F on FFFFFF: 8.48
  - highContrastDark `series2` A9CBFF on 000000: 12.67
  
  Every role in all 4 themes is at least 3.24. The minimum per theme: light 3.24, dark 4.21, highContrast 8.48, highContrastDark 12.38.
- `meetsGuideline` tests (text contrast, labelled tap target, iOS tap target) are present for 8 states in all 4 themes, and the whole `charts_test` passes.

## Animation
- With Reduce Motion on and then off, a bar chart with `animate: true` has `transientCallbackCount == 0` after the next frame: no replay (own probe).
- `CurvedAnimation` disposal: killed by the engineer's mutant 95 (re-run) and covered by the "every CurvedAnimation is disposed with its controller" test.
- Flake check, `--runs_per_test=50 --nocache_test_results` on `charts_test`, `golden_test`, `painter_test` and `geometry_test`: 4 of 4 PASSED, 0 failures (`flake-50.log`).

## AC5: gates
- `T-0059-AC5_gates.sh` (own output base): **PASS**, all 12 gates (tests, lint build, `mc_arch_check`, `rules_fork.sh check`, format on the gated directories only, `l10n_check`, provenance, fixtures closure, layering, no other package's goldens changed, no suppressions, coverage). Report: `ac5-gates.md`.
- `T-0059-AC5_layering.sh`: **PASS**; the allowed closure is theme, layout, tokens, feedback and (via feedback) buttons; positive controls and all negative controls (mc_paging, mc_feature_flow, mc_ds_inputs, a lower package naming the charts) are reported. Report: `ac5-layering.md`. Working tree stayed clean.
- `bazel test --lockfile_mode=error //...`: 182 of 182 tests pass.
- Coverage, own parser over the four `coverage.dat` files (union of the DA lines): **1025 / 1029 = 99.61 %** (threshold 90 %), min per file 98.4 % (`chart_math.dart`). Matches the engineer's figure (`coverage.txt`).
- Workspace `pubspec.yaml`: the only change is one line adding `utility/mc_ds_charts`, in the existing alphabetical-ish block. `tool/checks/` gets 2 new scripts.
- Integrity: AC1 to AC5 each have tests with `T-0059-ACn` in the name (AC1 11, AC2 102, AC3 59, AC4 30, AC5 13 occurrences). `grep` for `// ignore`, `ignore_for_file` and `skip:` finds nothing. The package is new, so no test or golden could have been deleted or weakened; no golden outside the package changed.

## Changes outside the package: `mc_ds_tokens`
`series1` to `series3` are new palette fields, in `==`, in `lerp` and in all 4 palettes; `positive`, `negative` and `neutral` are getters aliasing `success`, `error` and `outline`, so there is no new colour for them. The three series colours differ in hue (red, blue, teal), and each reaches 3:1 or more on `surface` in all 4 themes. Justified, accessible, and the sole token edit. No existing golden or test of other packages changed (gates PASS).

## Mutations
- Engineer's table, re-run by me on 10 mutants (indices 1, 6, 20, 30, 45, 60, 80, 95, 99, 100), the plain (non-golden) test files only: **10 of 10 killed** (`mutations-engineer-sample.log`).
- My own, 11 mutants against the plain tests (one over the budget of 10, because the 12th, a source-text mutant, did not apply and was skipped): 9 killed, **2 survived** (`mutations-verifier.log`).

| Mutant | Result |
|---|---|
| line zero line only when `min < 0` | killed |
| line zero line only when `max > 0` | killed |
| `_hasData` ignores the x-label truncation (`values.any` instead of `values.take(labels).any`) | **SURVIVED** |
| line series truncation to 3 removed | killed |
| `resolveAll`: previous ring neighbour ignored | killed |
| `resolveAll`: wrap-around neighbour ignored | killed |
| donut: minimum sweep never applied | killed |
| donut: pinned minimums not subtracted (sum not 360) | killed |
| `mcFormatValue` prints `-0` | killed |
| tick: `+ 1e-9` epsilon removed from the floor | **SURVIVED** |
| radar vertex y sign flipped | killed |

## Non-blocking findings (test gaps; the behaviour in the code is correct)
1. **`mc_line_chart.dart:381-385`** (`_hasData`): no test has a series whose only finite values lie beyond `xLabels.length` (release path, where the surplus values are ignored). Dropping `take(...)` would show a chart with no points instead of the empty view. Suggest one release-mode test, `McLineSeries(values: [NaN, NaN, 5])` with 2 labels, expecting the empty view.
2. **`chart_math.dart:101`** (`+ 1e-9` in the floor): no test pins the float-noise fix. `mcNiceTicks(0.3, 0.7)` gives `min = 0.3` with the epsilon, and 0.2 without it (`0.3 / 0.1 = 2.9999999999999996`), which would silently add a tick. Suggest a `geometry_test` case on `0.3..0.7` and `0.6..1.4`. The engineer's table already includes the "noise kept" mutant; this one is the ceiling/floor guard.

Both are outside the AC2 list of mandatory kills (ticks steps, zero line, sweep sum, minimum sweep), so they do not fail the AC; recommended as a follow-up in `pending-work.md`.

## Method notes
- The probe test was written in the package tree, run, copied to `verifier/probe_test.dart.txt` and removed from the tree. It needs a sibling `support/recording_canvas.dart` (in the package) to run.
- My first probe attempt used debug mode for a radar with a wrong series length, which throws by design (documented validation); I switched to the release override for the semantics check. No product defect.
- Engineer mutation script refuses a dirty tree; my evidence directory made the tree dirty, so I ran its table through `fvm flutter test` on the three plain test files instead, restoring with `git checkout -- utility/mc_ds_charts/lib` after each mutant. The golden-flagged mutants (which need Bazel) were not re-run by me.
