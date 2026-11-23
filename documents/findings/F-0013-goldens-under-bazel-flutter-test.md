# F-0013: Real-font goldens under Bazel `flutter_test` (where files live, how to update, fonts)

- **Date:** 2026-11-23
- **Author:** crew: Engineer (T-0019)
- **Type:** Gotcha
- **Related:** T-0019-AC1, F-0004 gotcha 1, plan 05 (Goldens L3), [evidence](../evidence/T-0019/engineer/)

## Summary
Goldens work under `bazel test` with real fonts, and regenerating them twice gives byte-identical PNGs (42 goldens over 4 packages). The setup is not obvious, so the facts are here.

## Facts
1. **Read path.** `matchesGoldenFile('goldens/x.png')` reads `<dir of the test main>/goldens/x.png` from runfiles. Every PNG must be in the target's `data`: `data = glob(["test/goldens/**"], allow_empty = True)`. `allow_empty` is needed or the BUILD file fails to load before the first goldens exist.
2. **Update.** `tool/bazelw run //pkg:golden_test -- --update-goldens` writes into the source tree (log: `wrote golden <abs source path>`). Run it, then `bazel test` to confirm.
3. **Fonts.** The tester disables asset fonts, so text is Ahem boxes **and every `Icon` is an empty box** (the MaterialIcons font is also disabled). `mcLoadFonts()` in `utility/mc_ds_theme/lib/mc_ds_golden.dart` registers Inter and MaterialIcons through `FontLoader`. No `flutter_test_config.dart` is needed.
4. **Locating font files.** In runfiles, `TEST_SRCDIR` is set. Inter is at `$TEST_SRCDIR/_main/utility/mc_ds_theme/assets/fonts/` and MaterialIcons at `$TEST_SRCDIR/ai_rules_flutter++flutter+flutter_material_fonts/material-fonts/MaterialIcons-Regular.otf` (from `@rules_flutter//flutter:material_icons`). Both are in the `//utility/mc_ds_theme:fonts` filegroup, which every golden target lists in `data`. The latter path embeds the bzlmod repo name and will change if rules_flutter is renamed or bumped. Plain `flutter test` falls back to `FLUTTER_ROOT`.
5. **Platform.** Set `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` inside the test body (reset in `finally`) and `ThemeData.platform` as well.
6. Golden targets are tagged `golden` and `target_compatible_with = macos`.

## Implications
- `mc_test_utils` should take over `mc_ds_golden.dart` (interim home: `mc_ds_theme`, which therefore depends on `flutter_test` in its `lib/`).
- Real app bundles still need Inter declared for the Bazel app target; only the pubspec `flutter: fonts:` declaration exists now (P-follow-up).
