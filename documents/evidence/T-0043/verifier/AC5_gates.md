# T-0043-AC5: pure Dart, registered, covered

## closure of mc_fixtures_discovery (1352 targets)
```
Flutter markers: none
```
## positive control: mc_fixtures_media
```
Flutter markers: @flutter_sky_engine//:sky_engine
@flutter_sky_engine//sky_engine:lib/_embedder.yaml
@flutter_sky_engine//sky_engine:lib/_empty.dart
```
## fixtures check (27 production targets scanned)
```
discovery dependencies: none
positive control (its own test): //utility/mc_fixtures_discovery:lib/mc_fixtures_discovery.dart //utility/mc_fixtures_discovery:lib/src/domain.dart 
negative control (dep added to characters_list): //feature/characters/characters_list:characters_list -> //utility/mc_fixtures_discovery:lib/mc_fixtures_discovery.dart //utility/mc_fixtures_discovery:lib/src/domain.dart //utility/mc_fixtures_discovery:lib/src/fixture_sets.dart 
```

| Gate | Result |
|---|---|
| pure-Dart closure | PASS |
| workspace registration | PASS |
| fixtures check | PASS |
| test discovery (uncached) | PASS |
| test //... | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | **FAIL** |
| l10n_check | PASS |
| coverage >= 90 % | PASS |

- discovery tests, uncached: Executed 4 out of 4 tests: 4 tests pass.
- test //...: Executed 0 out of 115 tests: 115 tests pass.
- mc_fixtures_discovery coverage: TOTAL 155/159 97.5% (threshold 90 %)

### dart format failed

```
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/src_import/feature/f_a/lib/src/f_a.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ad0ab6a4905ae3949/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/src_import/utility/u_base/lib/src/u_base.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ad0ab6a4905ae3949/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/src_import/utility/u_base/lib/u_base.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ad0ab6a4905ae3949/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/testing_import/feature/f_a/lib/f_a.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ad0ab6a4905ae3949/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/testing_import/feature/f_a/lib/src/f_a.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ad0ab6a4905ae3949/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/testing_import/feature/f_a/test/ok_test.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ad0ab6a4905ae3949/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/testing_import/utility/u_base/lib/src/u_base.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ad0ab6a4905ae3949/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/testing_import/utility/u_base/lib/testing.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ad0ab6a4905ae3949/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/utility_to_feature/feature/f_a/lib/f_a.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ad0ab6a4905ae3949/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/utility_to_feature/feature/f_a/lib/src/f_a.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ad0ab6a4905ae3949/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/utility_to_feature/utility/u_a/lib/src/u_a.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ad0ab6a4905ae3949/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/utility_to_feature/utility/u_a/lib/u_a.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ad0ab6a4905ae3949/tool/mc_arch_check/analysis_options.yaml".
Formatted 552 files (56 changed) in 0.45 seconds.
```

**FAIL T-0043-AC5-gates**
