# T-0051-AC5: pure Dart, registered, covered

## closure of mc_fixtures_commerce (1360 targets)
```
Flutter markers: none
```
## positive control: mc_fixtures_media
```
Flutter markers: @flutter_sky_engine//:sky_engine
@flutter_sky_engine//sky_engine:lib/_embedder.yaml
@flutter_sky_engine//sky_engine:lib/_empty.dart
```
## negative control: a throwaway target depending on the commerce package and on mc_fixtures_media
```
Flutter markers: @flutter_sky_engine//:sky_engine
@flutter_sky_engine//sky_engine:lib/_embedder.yaml
@flutter_sky_engine//sky_engine:lib/_empty.dart
throwaway package removed, tree clean: yes
```
## fixtures check (32 production targets scanned)
```
commerce dependencies: none
positive control (its own test): //utility/mc_fixtures_commerce:lib/mc_fixtures_commerce.dart //utility/mc_fixtures_commerce:lib/src/data/catalogue.dart 
negative control (a throwaway production target depending on it): //feature/zz_negctl_T0051/zz_negctl_T0051_prod:zz_negctl_prod -> //utility/mc_fixtures_commerce:lib/mc_fixtures_commerce.dart //utility/mc_fixtures_commerce:lib/src/data/catalogue.dart //utility/mc_fixtures_commerce:lib/src/data/pricing.dart 
throwaway package removed, tree clean: yes
```

| Gate | Result |
|---|---|
| pure-Dart closure | PASS |
| workspace registration | PASS |
| fixtures check | PASS |
| test commerce (uncached) | PASS |
| test //... | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| coverage >= 90 % | PASS |

- commerce tests, uncached: Executed 6 out of 6 tests: 6 tests pass.
- test //...: Executed 45 out of 150 tests: 150 tests pass.
- mc_fixtures_commerce coverage: TOTAL 388/393 98.7% (threshold 90 %)

**PASS T-0051-AC5-gates**
