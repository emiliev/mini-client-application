# T-0014-AC3: H-SDK evidence

| Check | Result |
|---|---|
| Bundled Dart (`dart-sdk/version` of the Bazel-fetched Flutter 3.47.7) | `3.13.5` |
| `dart --version` (that SDK) | `Dart SDK version: 3.13.5 (stable) (Tue Sep 29 01:00:52 2026 -0700) on "macos_arm64"` |
| Kernel format the stripper accepts | 138 (Dart 3.13.x); 3.13.5 is in range |
| Edit | `spike/greeting/lib/greeting.dart`: body-only (added a statement inside `greeting()`), then reverted |
| `greeting.flutter.koutline` (rules_flutter module) digest before / after | `27e3e5e0db0a525b` / `27e3e5e0db0a525b` |
| `greeting.koutline` (rules_dart DartKernel) digest before / after | `5eb766aca907b91b` / `5eb766aca907b91b` |
| `greeting.flutter.kmod` digest before / after (should change) | `ceb0f19ef5a78d69` / `489a9de50f7a7a3b` |
| Test after the edit | exit 0; INFO: 12 processes: 5 action cache hit, 7 disk cache hit, 5 internal. |
| "falling back to unstripped dill" in build logs | 0 |
| ... in `bazel-workers/*.log` | 0 |

Per-file koutline listing diff (empty = byte-identical):
```
```
