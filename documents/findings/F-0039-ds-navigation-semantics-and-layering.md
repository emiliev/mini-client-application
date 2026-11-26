# F-0039: McTabBar semantics roles, large-title bands, and what `mc_arch_check` does not enforce

- **Date:** 2026-11-26
- **Author:** crew: Engineer (T-0040)
- **Type:** Gotcha
- **Related:** T-0040-AC1, T-0040-AC2, T-0040-AC3, F-0014, F-0035

## Facts
1. **`SemanticsRole.tabBar` must sit directly above the tabs.** Flutter asserts "Children of TabBar must have the tab role" for every direct semantics child. A `Semantics(role: tabBar)` placed outside a `SingleChildScrollView` fails, because the scrollable's own node is the child. Place it inside the scroll view, around the `Row`, with `explicitChildNodes: true` (Material's `TabBar` does the same). Each tab is `Semantics(role: tab, selected:, button: true, label:, excludeSemantics: true)`.
2. **`flagsCollection.isSelected` is a `Tristate`** (`dart:ui`), not a bool; an unselected tab is `isFalse`, not `none`, when `selected: false` is given.
3. **`AppBar` already marks its title as a semantics header**, so wrapping the title again is redundant. A mutation of such a wrapper survives. The large title is drawn by us, so it carries its own `Semantics(header: true)`.
4. **A fixed-height band hides text-scale overflow.** The large-title `Text` under `Align` in a `SizedBox` gets loose constraints and clamps its height to the band; no overflow error is raised even at 3x, and the glyphs are painted outside. Asserting "no exception" proves nothing. The test reads the `Text.textScaler` instead (capped at `McAppBar.largeTitleMaxScale`, 1.5).
5. **`mc_arch_check` allows utility to utility edges.** Nothing stops `mc_ds_*` from depending on `mc_feature_flow`. T-0040-AC3 enforces it for `mc_ds_navigation` with `tool/checks/T-0040-AC3_layering.sh` (cquery closure, pubspec and import scan, with positive and negative controls). A general rule "`mc_ds_*` never depends on `mc_feature_flow`" belongs in `mc_arch_check` (follow-up).
6. **A scrollable tab bar must reveal the selected tab.** Without it a selected tab can be off screen (five tabs at 2x). `_TabItem` calls `Scrollable.ensureVisible` after the first frame and on selection change (zero duration on first build and under reduced motion).
