# F-0019: the dio cycle merge pulls Flutter into pure-Dart closures (T-0023)

- **Date:** 2026-11-24
- **Author:** crew: Engineer (T-0023)
- **Type:** Gotcha, upstream candidate
- **Related:** T-0023, F-0015, R15

## Summary
- `dio` and `dio_web_adapter` depend on each other. `rules_flutter` merges a pub dependency cycle into one target (`pub_deps__scc__dio__dio_web_adapter`), and because `dio_web_adapter` is Flutter-aware, the merged target is a **Flutter** target. Any pure-Dart `dart_library` that depends on `@pub_deps//:dio` then has `@pub_deps__flutter//:flutter` (and `sky_engine`) in its closure, and the codegen/analyzer summaries for it are disabled. The Verifier found this as the AC5 (Flutter-free, R15) failure of T-0023: `cquery 'deps(//utility/mc_api_client)'` showed `pub_deps__flutter`.
- The `package:flutter` import check (`no_flutter_test`) cannot see this; only the Bazel closure does.

## Workaround
`MODULE.bazel`, in `flutter.pub(name = "pub_deps", ...)`:

    cycle_breaks = {"dio": ["dio_web_adapter"]},

With it, `deps(//utility/mc_api_errors)` and `deps(//utility/mc_api_client)` contain no `sky_engine`, `pub_deps__flutter` or Flutter rules. `tool/checks/T-0023-AC5_flutter_free.sh` asserts this; it fails (checked) without the line.

## Upstream candidate
`rules_flutter` should break the dio / dio_web_adapter cycle by default (the web adapter is only needed on web), or decide "Flutter-ness" from the package's own `flutter` SDK dependency rather than from the merged component. Any other pure-Dart package that uses dio is affected the same way. Not filed yet; the TL decides.

## Implications
- New pure-Dart packages that use a package from a dependency cycle need the same `cycle_breaks` treatment and a closure check like the one above.
- In `cquery` output the repo name `ai_rules_flutter++flutter+` appears on pure-Dart targets too (toolchain and every pub repo). Grep for `sky_engine`, `pub_deps__flutter` and `//flutter:`, not for "flutter".
