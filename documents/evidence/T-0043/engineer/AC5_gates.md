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
| dart format | PASS |
| l10n_check | PASS |
| coverage >= 90 % | PASS |

- discovery tests, uncached: Executed 4 out of 4 tests: 4 tests pass.
- test //...: Executed 0 out of 115 tests: 115 tests pass.
- mc_fixtures_discovery coverage: TOTAL 143/147 97.3% (threshold 90 %)

**PASS T-0043-AC5-gates**
