# F-0043: DS inputs: text-field semantics, live-region errors, ink under fills, and what the contrast guideline skips

- **Date:** 2026-11-26
- **Author:** crew: Engineer (T-0044)
- **Type:** Gotcha
- **Related:** T-0044-AC1, T-0044-AC2, T-0044-AC3, F-0014, F-0039

## Facts
1. **A `TextField`'s label is on a child semantics node.** `tester.getSemantics(find.byType(TextField))` returns the route's root node (empty label); the field's node holds `label: "Email"` and `isTextField`, and the helper text is its own child node. Find fields with `find.bySemanticsLabel('Email')`.
2. **`InputDecoration.errorText` is not a live region.** The error is a plain text node, so a screen reader does not announce it when it appears. `mcFieldDecoration` passes `error: Semantics(liveRegion: true, child: Text(...))` instead; a widget `error` still switches the borders and the label to the error state. A test reads `flagsCollection.isLiveRegion`.
3. **`meetsGuideline(textContrastGuideline)` skips text fields**, and a mutation that turned the label colour into the fill colour survived it. Contrast of the label, hint, helper, counter and typed text is asserted against the field's `fillColor` from the `InputDecorator`, in every theme (`T-0044-AC3 text field colours reach 4.5:1`).
4. **The guidelines sample pixels by semantics rect and misread a tall mixed page.** One page with 12 widgets reported "1.35:1" for an error text in dark theme only; each widget alone passed. The guideline test pumps one widget per page.
5. **Ink under a `DecoratedBox` is invisible.** A selected segment filled with `Ink(color:)` inside a `DecoratedBox(color: surface)` drew nothing (selected text, `onPrimary`, was white on white; the guideline caught it as "1.00:1"). The `Material` must be inside the fill: `Material(color: surface)` with the outline as a foreground `DecoratedBox`. Chips use `Ink(decoration:)` on the transparent `Material`, which works because nothing paints above it.
6. **A disabled selected control needs `onPrimary` text.** Filled with the muted colour, muted text vanished. Foreground is `selected ? onPrimary : (enabled ? onSurface : onSurfaceMuted)`.
7. **A non-const expression in a `const` constructor gives a misleading Bazel error:** `export 'src/x.dart' reaches a source its dependencies define under 'package:...'`. The real cause was `const EdgeInsets.symmetric(horizontal: segments.length > 3 ? ...)`; `fvm flutter analyze lib` names it at once.
8. **Bazel tests fail on unformatted test files before they run**, and `grep` filters on the output showed nothing. Run `fvm dart format` before each `bazel test`.
9. **A tap target can hold only by accident.** A chip is 44 pt tall at 1x because Inter's line plus padding add up to 44, so removing `minHeight: 44` is an equivalent mutant at 1x. A test at 0.5x text scale makes the minimum matter.
10. **A `TextField` needs a bounded width.** In a `Row` without `Expanded` it throws; `boundedFieldWidth` gives it `mcFieldUnboundedWidth` (280) when unbounded. `McSegmented` switches to natural widths, `McChipGroup` is a `Wrap`, `McStepper` is as wide as its content.
11. **Fixed icon sizes do not follow the text scale.** Chip and segment icons use `textScaler.scale(18)` (segments are capped at 1.5x with their labels).
