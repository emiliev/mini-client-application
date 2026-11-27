# T-0061-AC5: pure Dart, registered, covered

## closure of mc_fixtures_identity (1334 targets)
```
Flutter markers: none
```
## positive control: mc_fixtures_media
```
Flutter markers: @flutter_sky_engine//:sky_engine
@flutter_sky_engine//sky_engine:lib/_embedder.yaml
@flutter_sky_engine//sky_engine:lib/_empty.dart
```
## negative control: a throwaway target depending on the identity package and on mc_fixtures_media
```
Flutter markers: @flutter_sky_engine//:sky_engine
@flutter_sky_engine//sky_engine:lib/_embedder.yaml
@flutter_sky_engine//sky_engine:lib/_empty.dart
throwaway package removed, tree clean: yes
```
## fixtures check (36 production targets scanned)
```
identity dependencies: none
positive control (its own test): //utility/mc_fixtures_identity:identity_test //utility/mc_fixtures_identity:lib/mc_fixtures_identity.dart 
negative control (a throwaway production target depending on it): //feature/zz_negctl_T0061/zz_negctl_T0061_prod:zz_negctl_prod -> //utility/mc_fixtures_identity:lib/mc_fixtures_identity.dart //utility/mc_fixtures_identity:lib/src/data/users.dart //utility/mc_fixtures_identity:lib/src/domain.dart 
throwaway package removed, tree clean: yes
```

| Gate | Result |
|---|---|
| pure-Dart closure | PASS |
| workspace registration | PASS |
| fixtures check | PASS |
| negative controls created | PASS |
| test identity (uncached) | PASS |
| test //... (--lockfile_mode=error) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| coverage >= 90 % | PASS |

- identity tests, uncached: Executed 4 out of 4 tests: 4 tests pass.
- test //...: Executed 114 out of 191 tests: 191 tests pass.
- mc_fixtures_identity coverage: TOTAL 208/210 99.0% (threshold 90 %)

**PASS T-0061-AC5-gates**
