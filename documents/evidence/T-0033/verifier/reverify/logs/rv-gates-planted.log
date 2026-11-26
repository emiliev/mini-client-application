# T-0033-AC5: gates and fixtures closure

| Gate | Result |
|---|---|
| test //... (T-0033 packages uncached) | **FAIL** |
| build --config=lint //... | **FAIL** |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | **FAIL** |
| l10n_check | PASS |
| fixtures closure (T-0031-AC6 widened) | PASS |
| apps build for the simulator | PASS |

- tests: Executed 0 out of 7 tests: 7 were skipped.

### test //... (T-0033 packages uncached) failed

```
INFO: Invocation ID: 6c88622f-75f9-4590-a2c9-06cbc6f60e1f
Computing main repo mapping: 
Loading: 
Loading: 0 packages loaded
Analyzing: 21 targets (2 packages loaded, 0 targets configured)
Analyzing: 21 targets (2 packages loaded, 0 targets configured)

INFO: Analyzed 21 targets (5 packages loaded, 100 targets configured, 95 aspect applications).
ERROR: /Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a7d7b3473200bf2cd/app/wiring/universe_wiring/BUILD.bazel:94:16: Checking Dart formatting of //app/wiring/universe_wiring:universe_wiring failed: (Exit 1): dart failed: error executing DartFormat command (from aspects [@@ai_rules_dart+//dart/private:dart_analyzer_summary.bzl%dart_analyzer_summary, @@ai_rules_dart+//dart/private:dart_analyze_aspect.bzl%dart_analyze] on flutter_library rule target //app/wiring/universe_wiring:universe_wiring) external/ai_rules_flutter++flutter+flutter_darwin-arm64/dart-sdk/bin/dart bazel-out/darwin_arm64-opt-exec/bin/external/ai_rules_dart+/dart/private/tools/format_runner.dill ... (remaining 1 argument skipped)
Changed app/wiring/universe_wiring/lib/src/zz_verifier_unformatted.dart
Formatted 9 files (1 changed) in 0.22 seconds.
Use --verbose_failures to see the command lines of failed build steps.
INFO: Elapsed time: 1.044s, Critical Path: 0.65s
INFO: 36 processes: 7164 action cache hit, 2 disk cache hit, 28 internal, 2 darwin-sandbox, 4 worker.
ERROR: Build did NOT complete successfully
//app/mini_client:app_test                                            NO STATUS
//app/sandbox/universe_sandbox:universe_sandbox_links_test            NO STATUS
//app/sandbox/universe_sandbox:universe_sandbox_router_test           NO STATUS
//app/wiring/app_core:boot_test                                       NO STATUS
//app/wiring/app_core:links_and_hooks_test                            NO STATUS
//app/wiring/app_core:router_ref_and_scheme_test                      NO STATUS
//app/wiring/universe_wiring:routes_test                              NO STATUS

Executed 0 out of 7 tests: 7 were skipped.
```

### build --config=lint //... failed

```
INFO: Invocation ID: d5b95383-b5e3-43d3-ad2a-711b4b13bf81
Computing main repo mapping: 
Loading: 
Loading: 0 packages loaded
Analyzing: 203 targets (17 packages loaded, 0 targets configured)
Analyzing: 203 targets (17 packages loaded, 18 targets configured)

ERROR: /Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a7d7b3473200bf2cd/app/wiring/universe_wiring/BUILD.bazel:94:16: Checking Dart formatting of //app/wiring/universe_wiring:universe_wiring failed: (Exit 1): dart failed: error executing DartFormat command (from aspects [@@ai_rules_dart+//dart/private:dart_analyzer_summary.bzl%dart_analyzer_summary, @@ai_rules_dart+//dart/private:dart_analyze_aspect.bzl%dart_analyze] on flutter_library rule target //app/wiring/universe_wiring:universe_wiring) external/ai_rules_flutter++flutter+flutter_darwin-arm64/dart-sdk/bin/dart bazel-out/darwin_arm64-opt-exec/bin/external/ai_rules_dart+/dart/private/tools/format_runner.dill ... (remaining 1 argument skipped)
Changed app/wiring/universe_wiring/lib/src/zz_verifier_unformatted.dart
Formatted 9 files (1 changed) in 0.08 seconds.
INFO: Elapsed time: 1.057s, Critical Path: 0.10s
INFO: 4 processes: 5192 action cache hit, 4 internal.
ERROR: Build did NOT complete successfully
```

### dart format failed

```
Changed app/wiring/universe_wiring/lib/src/zz_verifier_unformatted.dart
Formatted 385 files (1 changed) in 0.33 seconds.
```

**FAIL T-0033-AC5-gates**
