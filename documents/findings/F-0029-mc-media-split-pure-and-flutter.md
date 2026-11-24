# F-0029: `mc_media` is two Bazel libraries, so pure-Dart closures stay Flutter-free

- **Date:** 2026-11-25
- **Author:** crew: Engineer (T-0030)
- **Type:** Gotcha / design deviation
- **Related:** T-0030-AC6, T-0030-AC7, F-0013, T-0023-AC5, plan 01 U14 and U39

## Summary
1. **One Flutter library in a pure closure breaks the kernel compile.** A first cut put `McMediaScope` (an `InheritedWidget`) and `McImageResolver` in one `flutter_library` named `mc_media`. `mc_fixtures_media` then depended on it. `//utility/mc_api_client:api_client_test` is a `dart_test` that reaches `mc_fixtures_media` through `mc_fixtures_characters`, and it failed to build with `kernel_module: cannot compile package:flutter/...: import 'constants.dart' reaches a source its dependencies define under 'package:flutter/src/gestures/constants.dart'`. The mocked-backend fixtures chain is consumed by pure-Dart tests, so it must stay pure.
2. **The fix is a split with one package name.** `//utility/mc_media:mc_media` is a `dart_library` (ApiImage, ImageVariant, `McImageResolver`, `ResolvedImage`) behind the barrel `package:mc_media/mc_media.dart`. `//utility/mc_media:mc_media_scope` is a `flutter_library` of the same `package_name` (McMediaScope) behind its own barrel `package:mc_media/mc_media_scope.dart`. rules_dart accepts two libraries of one package name when their files differ. Flutter widgets import the scope barrel; everything else imports the pure one.
3. **Consequence for the interface.** `ResolvedImage` has only `variant`; it has no `ImageProvider`, because `package:flutter/painting.dart` would make the pure library Flutter. `BundledImage` keeps `assetKey`. The P1-12 `McImage` widget decides how a `ResolvedImage` becomes an `ImageProvider` (for example a `McMediaScope`-side factory or a switch on the resolved type).
4. **Checks.** `tool/checks/T-0030-AC7_closure.sh` runs `cquery deps(...)` for `mc_paging` and the pure `mc_media`, requires no Flutter marker, and includes a positive control: `mc_media_scope` must show markers. With `mc_media_scope` added to `mc_paging`'s deps, the script reports Flutter markers and exits 1 (`documents/evidence/T-0030/engineer/AC7_negative_control.md`). `mc_media` has a source-level `purity_test` for its three pure files.
5. **`freezed` on a generic class works under the shim.** `PagedState<T>` uses a bare `@freezed` with `@Default(<Never>[]) List<T> items`; the `dart_codegen` freezed action output compiles and analyzes (no JSON, so R30 doesn't apply). The generated `.freezed.dart` contains `mixin _$PagedState`. The "no mixins in `mc_paging`" rule is about hand-written declarations (`purity_test` scans `lib/**` sources, not generated output); the generated mixin is outline-cutoff-relevant only for the generated file, which is a leaf. Worth a TL look if the cutoff rule is meant to cover generated mixins.

## Implications / actions
- Any new package that fixtures or pure tests depend on must keep Flutter out of its closure; check with `cquery`.
- Follow-up for P1-12: `McImage` resolves a `ResolvedImage` to an `ImageProvider`.
- Follow-up: `mc_paging` does not depend on `mc_bloc_kit`, although plan 01 U19 lists it. The controller is a plain helper with a callback, so there is nothing to import. The edge can be added when a bloc-based helper needs it.
