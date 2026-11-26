# T-0035-AC4: gates and coverage

| Gate | Result |
|---|---|
| test //... (touched packages uncached) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| flow_builder provenance (evergreen) | PASS |
| lock delta vs 6e7eaaf (one-off, pre-merge) | **FAIL** |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 11 out of 84 tests: 84 tests pass.
- coverage: == utility/mc_feature_flow TOTAL 143/144 99.3% == feature/characters/characters_list TOTAL 155/155 100.0% (threshold 90 %)

### lock delta vs 6e7eaaf (one-off, pre-merge) failed

```
# T-0035-AC4: lock delta against base 6e7eaaf (one-off)

| Check | Result | Required |
|---|---|---|
| pubspec.lock = base minus the flow_builder block | DIFFERS: 168a169,173
>   flutter_driver:
>     dependency: transitive
>     description: flutter
>     source: sdk | identical |
| MODULE.bazel.lock = base minus the flow_builder repo and mentions | DIFFERS | equal |

**FAIL T-0035-AC4-lock-delta**
```

**FAIL T-0035-AC4-gates**
