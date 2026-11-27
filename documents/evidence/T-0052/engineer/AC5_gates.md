# T-0052-AC5: pure Dart, registered, covered

## positive control: the closure of mc_fixtures_media
```
Flutter markers: @flutter_sky_engine//:sky_engine
@flutter_sky_engine//sky_engine:lib/_embedder.yaml
@flutter_sky_engine//sky_engine:lib/_empty.dart
```
## closure of mc_fixtures_platform (1339 targets)
```
Flutter markers: none
```
## negative control: a throwaway target depending on mc_fixtures_platform and on mc_fixtures_media
```
Flutter markers: @flutter_sky_engine//:sky_engine
@flutter_sky_engine//sky_engine:lib/_embedder.yaml
@flutter_sky_engine//sky_engine:lib/_empty.dart
throwaway package removed, tree clean: yes
```
## closure of mc_feature_flags (2964 targets)
```
Flutter markers: none
```
## negative control: a throwaway target depending on mc_feature_flags and on mc_fixtures_media
```
Flutter markers: @flutter_sky_engine//:sky_engine
@flutter_sky_engine//sky_engine:lib/_embedder.yaml
@flutter_sky_engine//sky_engine:lib/_empty.dart
throwaway package removed, tree clean: yes
```
## fixtures check (33 production targets scanned)
```
mc_fixtures_platform dependencies: none
positive control (a test of mc_feature_flags): //utility/mc_fixtures_platform:lib/mc_fixtures_platform.dart //utility/mc_fixtures_platform:lib/src/data/flags.dart 
negative control (a throwaway production target depending on it): //feature/zz_negctl_T0052/zz_negctl_T0052_prod:zz_negctl_prod -> //utility/mc_fixtures_platform:lib/mc_fixtures_platform.dart //utility/mc_fixtures_platform:lib/src/data/flags.dart //utility/mc_fixtures_platform:lib/src/domain.dart 
throwaway package removed, tree clean: yes
```

| Gate | Result |
|---|---|
| pure-Dart closure: mc_fixtures_platform | PASS |
| pure-Dart closure: mc_feature_flags | PASS |
| workspace registration: mc_feature_flags | PASS |
| workspace registration: mc_fixtures_platform | PASS |
| fixtures check | PASS |
| test both packages (uncached) | PASS |
| test //... | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| sim apps build (--config=sim) | PASS |
| coverage >= 90 % | PASS |

- the two packages' tests, uncached: Executed 10 out of 10 tests: 10 tests pass.
- test //...: Executed 62 out of 163 tests: 163 tests pass.
- coverage (mc_feature_flags, then mc_fixtures_platform): TOTAL 416/423 98.3% TOTAL 51/55 92.7%  (threshold 90 %)

**PASS T-0052-AC5-gates**
