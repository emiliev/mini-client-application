# T-0029-AC2: missing steps fail the build, nothing is written

## `//spike/bdd_sample/test/negative:missing_step` (exit 1)
```
BDD generation failed: missing_step.feature: 2 step(s) have no definition:
  "I count {3} craters" -> step/i_count_craters.dart (iCountCraters)
  "the moon is made of cheese" -> step/the_moon_is_made_of_cheese.dart (theMoonIsMadeOfCheese)
Write them, or run the scaffold tool to create stubs; the build never writes into the source tree.
Target //spike/bdd_sample/test/negative:missing_step failed to build
Use --verbose_failures to see the command lines of failed build steps.
INFO: Elapsed time: 9.405s, Critical Path: 9.16s
INFO: 60 processes: 19 internal, 8 darwin-sandbox, 33 worker.
ERROR: Build did NOT complete successfully
```
- names `2 step(s) have no definition`
- names `"the moon is made of cheese" -> step/the_moon_is_made_of_cheese.dart`
- names `"I count {3} craters" -> step/i_count_craters.dart`
## `//spike/bdd_sample/test/negative:shadowed_step` (exit 1)
```
BDD generation failed: shadowed_step.feature: local step(s) shadow shared steps of the same name:
  step/i_see.dart shadows package:mc_test_steps/mc_test_steps.dart
Delete the local step or rename it.
Target //spike/bdd_sample/test/negative:shadowed_step failed to build
Use --verbose_failures to see the command lines of failed build steps.
INFO: Elapsed time: 0.109s, Critical Path: 0.02s
INFO: 2 processes: 2 internal.
ERROR: Build did NOT complete successfully
```
- names `step/i_see.dart shadows package:mc_test_steps/mc_test_steps.dart`

- source tree unchanged (every file under spike/bdd_sample hashed, plus `git status --ignored`)

**PASS T-0029-AC2**
