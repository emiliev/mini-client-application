# T-0047-AC5: pure Dart, registered, covered

## closure of mc_fixtures_library (1358 targets)
```
Flutter markers: none
```
## positive control: mc_fixtures_media
```
Flutter markers: @flutter_sky_engine//:sky_engine
@flutter_sky_engine//sky_engine:lib/_embedder.yaml
@flutter_sky_engine//sky_engine:lib/_empty.dart
```
## negative control: a Flutter-bound dependency added to the library
```
Flutter markers: @flutter_sky_engine//:sky_engine
@flutter_sky_engine//sky_engine:lib/_embedder.yaml
@flutter_sky_engine//sky_engine:lib/_empty.dart
BUILD restored byte-for-byte: yes
```
## fixtures check (30 production targets scanned)
```
library dependencies: none
positive control (its own test): //utility/mc_fixtures_library:lib/mc_fixtures_library.dart //utility/mc_fixtures_library:lib/src/data/reading_list.dart 
negative control (dep added to characters_list): //feature/characters/characters_list:characters_list -> //utility/mc_fixtures_library:lib/mc_fixtures_library.dart //utility/mc_fixtures_library:lib/src/data/reading_list.dart //utility/mc_fixtures_library:lib/src/domain.dart 
BUILD restored byte-for-byte: yes
```

| Gate | Result |
|---|---|
| pure-Dart closure | PASS |
| workspace registration | PASS |
| fixtures check | PASS |
| test library (uncached) | PASS |
| test //... | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| coverage >= 90 % | PASS |

- library tests, uncached: Executed 4 out of 4 tests: 4 tests pass.
- test //...: Executed 0 out of 127 tests: 127 tests pass.
- mc_fixtures_library coverage: TOTAL 194/197 98.5% (threshold 90 %)

**PASS T-0047-AC5-gates**
