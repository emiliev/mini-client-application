# T-0060-AC5: pure Dart, registered, covered

## closure of mc_fixtures_editorial (1360 targets)
```
Flutter markers: none
```
## positive control: mc_fixtures_media
```
Flutter markers: @flutter_sky_engine//:sky_engine
@flutter_sky_engine//sky_engine:lib/_embedder.yaml
@flutter_sky_engine//sky_engine:lib/_empty.dart
```
## negative control: a throwaway target depending on the editorial package and on mc_fixtures_media
```
Flutter markers: @flutter_sky_engine//:sky_engine
@flutter_sky_engine//sky_engine:lib/_embedder.yaml
@flutter_sky_engine//sky_engine:lib/_empty.dart
throwaway package removed, tree clean: yes
```
## fixtures check (35 production targets scanned)
```
editorial dependencies: none
positive control (its own test): //utility/mc_fixtures_editorial:determinism_test //utility/mc_fixtures_editorial:lib/mc_fixtures_editorial.dart 
negative control (a throwaway production target depending on it): //feature/zz_negctl_T0060/zz_negctl_T0060_prod:zz_negctl_prod -> //utility/mc_fixtures_editorial:lib/mc_fixtures_editorial.dart //utility/mc_fixtures_editorial:lib/src/data/bank.dart //utility/mc_fixtures_editorial:lib/src/data/round.dart 
throwaway package removed, tree clean: yes
```

| Gate | Result |
|---|---|
| pure-Dart closure | PASS |
| workspace registration | PASS |
| fixtures check | PASS |
| test editorial (uncached) | PASS |
| test //... | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| coverage >= 90 % | PASS |

- editorial tests, uncached: Executed 5 out of 5 tests: 5 tests pass.
- test //...: Executed 15 out of 187 tests: 187 tests pass.
- mc_fixtures_editorial coverage: TOTAL 454/456 99.6% (threshold 90 %)

**PASS T-0060-AC5-gates**
