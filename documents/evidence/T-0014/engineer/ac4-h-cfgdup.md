# T-0014-AC4: H-CFGDUP execution-log counts

One Bazel server, after `tool/bazelw clean`, with the disk cache off (`--config=cold`):

1. `tool/bazelw build --config=sim --config=cold --execution_log_json_file=<abs>/exec_sim.json //spike/hello:hello_ios` (3450 processes)
2. `tool/bazelw test --config=cold --execution_log_json_file=<abs>/exec_host.json //spike/hello:widget_test` (3815 processes; the 95 action-cache hits are exec-configuration tools shared with step 1)

Counted with [`cfgdup.py`](cfgdup.py). The logs (40 MB) are not committed.

**Result:** DartCodegen is duplicated **3 of 3**. DartKernel has **1** duplicate with an identical output path (`//spike/greeting`, the rules_dart kernel). On top of that, **12 of 32** non-exec targets are compiled as two different Flutter kernel variants: `.flutter.kmod` for the test and `.app_debug.flutter.kmod` for the app.

## Dart actions per mnemonic and configuration (both invocations)

| Mnemonic | Configuration | Actions |
|---|---|---|
| DartAnalyze | `darwin_arm64-fastbuild` | 1 |
| DartAnalyzerSummary | `darwin_arm64-fastbuild` | 30 |
| DartAnalyzerSummary | `ios_sim_arm64-dbg-ios-sim_arm64-min15.0-ST-8f99be897b7e` | 4 |
| DartCodegen | `darwin_arm64-fastbuild` | 3 |
| DartCodegen | `ios_sim_arm64-dbg-ios-sim_arm64-min15.0-ST-8f99be897b7e` | 3 |
| DartFormat | `darwin_arm64-fastbuild` | 1 |
| DartKernel | `darwin_arm64-fastbuild` | 32 |
| DartKernel | `darwin_arm64-opt-exec` | 48 |
| DartKernel | `darwin_arm64-opt-exec-ST-af20dd4d9e84` | 6 |
| DartKernel | `ios_sim_arm64-dbg-ios-sim_arm64-min15.0-ST-8f99be897b7e` | 15 |
| DartKernelLink | `darwin_arm64-fastbuild` | 2 |
| DartKernelLink | `darwin_arm64-opt-exec` | 3 |
| DartKernelLink | `ios_sim_arm64-dbg-ios-sim_arm64-min15.0-ST-8f99be897b7e` | 1 |

## Duplicated across configurations (same mnemonic, target and output path minus `bazel-out/<config>/`)

| Mnemonic | Distinct actions | Duplicated in 2+ configs |
|---|---|---|
| DartKernel | 100 | 1 |
| DartCodegen | 3 | 3 |
| DartAnalyzerSummary | 30 | 4 |
| DartKernelLink | 6 | 0 |
| DartAnalyze | 1 | 0 |
| DartFormat | 1 | 0 |

First-party duplicates:
- DartCodegen `//spike/hello:counter_state_freezed`: `darwin_arm64-fastbuild` and the iOS-simulator configuration
- DartCodegen `//spike/hello:routes_g`: the same two
- DartCodegen `//spike/hello:routes_go_router_part`: the same two
- DartKernel `//spike/greeting:greeting`: the same two

## By target label (non-exec configurations)

- **DartKernel:** 12 of 32 targets are compiled in both `darwin_arm64-fastbuild` and the simulator configuration. Their outputs have different names (`<pkg>.flutter.kmod` and `<pkg>.app_debug.flutter.kmod`), so they are different products, not just the same product at another path. Path mapping (U-D8) would not merge them.
- **DartCodegen:** 3 of 3 targets run twice, with identical inputs and the same output under two output roots. Path mapping (U-D8) would merge these.
