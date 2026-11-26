# T-0038-AC4: pure Dart, registered, covered

## closure of mc_fixtures_comics (1338 targets)
```
Flutter markers: none
```
## positive control: mc_fixtures_characters
```
Flutter markers: @flutter_sky_engine//:sky_engine
@flutter_sky_engine//sky_engine:lib/_embedder.yaml
@flutter_sky_engine//sky_engine:lib/_empty.dart
```
## fixtures check (23 production targets scanned)
```
comics dependencies: none
positive control (its own test): //utility/mc_fixtures_comics:comics_test //utility/mc_fixtures_comics:lib/mc_fixtures_comics.dart 
negative control (dep added to characters_list): //feature/characters/characters_list:characters_list -> //utility/mc_fixtures_comics:lib/mc_fixtures_comics.dart //utility/mc_fixtures_comics:lib/src/data/links.dart //utility/mc_fixtures_comics:lib/src/data/universe.dart 
```

| Gate | Result |
|---|---|
| pure-Dart closure | PASS |
| workspace registration | PASS |
| fixtures check | PASS |
| test //... (comics uncached) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | **FAIL** |
| l10n_check | PASS |
| coverage >= 90 % | PASS |

- tests: Executed 0 out of 88 tests: 88 tests pass.
- mc_fixtures_comics coverage: TOTAL 228/232 98.3% (threshold 90 %)

### dart format failed

```
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/src_import/feature/f_a/lib/src/f_a.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/src_import/utility/u_base/lib/src/u_base.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/src_import/utility/u_base/lib/u_base.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/testing_import/feature/f_a/lib/f_a.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/testing_import/feature/f_a/lib/src/f_a.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/testing_import/feature/f_a/test/ok_test.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/testing_import/utility/u_base/lib/src/u_base.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/testing_import/utility/u_base/lib/testing.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/utility_to_feature/feature/f_a/lib/f_a.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/utility_to_feature/feature/f_a/lib/src/f_a.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/utility_to_feature/utility/u_a/lib/src/u_a.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76/tool/mc_arch_check/analysis_options.yaml".
Warning: Package resolution error when reading "analysis_options.yaml" file for "tool/mc_arch_check/test/fixtures/utility_to_feature/utility/u_a/lib/u_a.dart":
Failed to resolve package URI "package:mc_analysis/analysis_options.yaml" in include at "/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76/tool/mc_arch_check/analysis_options.yaml".
Formatted 409 files (27 changed) in 0.27 seconds.
```

**FAIL T-0038-AC4-gates**
