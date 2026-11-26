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
| test comics (uncached) | PASS |
| test //... | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| coverage >= 90 % | PASS |

- comics tests, uncached: Executed 3 out of 3 tests: 3 tests pass.
- test //...: Executed 0 out of 88 tests: 88 tests pass.
- mc_fixtures_comics coverage: TOTAL 231/234 98.7% (threshold 90 %)

**PASS T-0038-AC4-gates**
