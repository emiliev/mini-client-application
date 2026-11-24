# U-X-injectable-lean_builder: injectable_generator / lean_builder, the analyzer range

| | |
|---|---|
| Targets | https://github.com/Milad-Akarie/injectable (issue) and lean_builder's repository (issue; also by Milad Akarie, see its pub.dev page) |
| Task | T-0028; plan 03 X3; finding F-0028 |
| Status | Draft, not sent (Q-013) |

## Issue 1, injectable: "injectable_generator forces lean_builder (and an old _fe_analyzer_shared) on build_runner users"

**Title:** injectable_generator 3.1.3 can't be used with analyzer 14.5+ because of the lean_builder dependency

**Body:**

`injectable_generator` 3.1.3 declares `analyzer: ">=10.0.0 <15.0.0"`, but also
`lean_builder: ^1.2.2`, and lean_builder 1.2.2 requires
`_fe_analyzer_shared: ">=98.0.0 <106.0.0"`. analyzer 14.5.0 requires
`_fe_analyzer_shared ^109.0.0`. In practice pub settles on analyzer 14.1.0
(`_fe_analyzer_shared` 105.0.0), and a project whose other generators or tools pin a newer
analyzer can't resolve at all.

lean_builder is only used by the optional `lib/lean_builder/` integration. The build_runner
builders (`lib/builder.dart`: `injectableBuilder`, `injectableConfigBuilder`) import only
`package:build` and `package:source_gen`. We confirmed this by vendoring 3.1.3 with
`lib/lean_builder/` removed: it compiles against analyzer 14.5.0, and its output (run through
rules_dart's builder shim) is byte-identical to stock 3.1.3 under build_runner.

Repro:

```yaml
dev_dependencies:
  analyzer: 14.5.0
  injectable_generator: 3.1.3
```
`dart pub get` (Dart 3.13.5) fails version solving on lean_builder's `_fe_analyzer_shared`
bound. Without the analyzer pin it resolves analyzer 14.1.0.

Proposals (either works for us):
1. Move the lean_builder integration into its own package (e.g. `injectable_lean_builder`),
   so `injectable_generator` depends only on build / source_gen / analyzer.
2. Or keep it, but widen lean_builder's bound (issue 2) and release a 3.1.4.

## Issue 2, lean_builder: "widen _fe_analyzer_shared to <112"

**Title:** Allow `_fe_analyzer_shared` up to <112 (analyzer 14.5+)

**Body:**

lean_builder 1.2.2 pins `_fe_analyzer_shared: ">=98.0.0 <106.0.0"` while allowing
`analyzer: ">=10.0.0 <15.0.0"`. analyzer 14.5.0 needs `_fe_analyzer_shared ^109.0.0`, so the
upper part of the analyzer range is unreachable (pub settles on 14.1.0) and every dependent (injectable_generator 3.1.x) is
stuck there. Could the bound be widened to `<112.0.0` (after a test run against 109/111)?

## Effect on our side
When either lands, rules_dart can depend on `injectable_generator` from pub directly: add it to
`dart/ext/pubspec.yaml`, relock, point the shims at `@ext_pub_deps//:injectable_generator` and
delete `dart/ext/injectable/third_party/` (steps in its `VENDORED.md`).
