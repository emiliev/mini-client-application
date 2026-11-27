# T-0053-AC5: gates

## closure of mc_analytics (2380 targets)
```
network or SDK markers: none
```
## positive control: mc_api_client
```
markers: @@ai_rules_flutter++flutter+pub_deps__dio//:LICENSE
@@ai_rules_flutter++flutter+pub_deps__dio//:dio
@@ai_rules_flutter++flutter+pub_deps__dio//:lib/browser.dart
```
## negative control: a throwaway target depending on mc_analytics and mc_api_client
```
markers: @@ai_rules_flutter++flutter+pub_deps__dio//:LICENSE
@@ai_rules_flutter++flutter+pub_deps__dio//:dio
@@ai_rules_flutter++flutter+pub_deps__dio//:lib/browser.dart
throwaway package removed, tree clean: yes
```
## globs over lib/** use MC_GENERATED_DART
```
real BUILD: exit 0 (0 = every glob excludes it)
control without the exclusion: exit 1 (must be 1)
```

| Gate | Result |
|---|---|
| no network client or SDK in the closure | PASS |
| globs use MC_GENERATED_DART | PASS |
| workspace registration | PASS |
| test //... (touched packages uncached) | PASS |
| test --lockfile_mode=error //... | PASS |
| bundled configs (dev, e2e, perf) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 40 out of 40 tests: 40 tests pass.
- coverage: == utility/mc_analytics TOTAL 293/293 100.0% == utility/mc_config TOTAL 24/24 100.0% == app/wiring/app_core TOTAL 437/454 96.3% == app/mini_client TOTAL 109/114 95.6% (threshold 90 %)

**PASS T-0053-AC5-gates**
