# Verification report — T-0017: Workspace skeleton, architecture guard, `mc_analysis`, `mc_prelude`, `mc_di`

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-23
- **Branch / commit verified:** `fleet/T-0017-foundation` @ **`873500c`** (re-verification). Checked out as `fleet/T-0017-verify2`. The first round was `26fada6`, verdict FAIL, report `c22a432` on `fleet/T-0017-verify`.
- **Bazel:** own output base `/tmp/mc-verify-t0017`, server shut down afterwards
- **Simulator:** none (no UI, no e2e in scope)
- **Verdict:** **PASS**. All 8 ACs pass. The round-1 AC4 failure is fixed: `mc_arch_check` now reads directives with `package:analyzer`, so relative exports, wildcard exports and the `if (...)` alternatives of conditional imports and exports are all checked.

## Gates re-run independently (at 873500c)
| Gate | Command | Result |
|---|---|---|
| Bazel tests with the analyze and format aspect | `tool/bazelw --output_base=/tmp/mc-verify-t0017 test --disk_cache= --nocache_test_results //...` | 5/5 targets PASS, run fresh with no disk cache (`verifier/bazel-gates.log`) |
| Lint | `tool/bazelw … build --disk_cache= --config=lint //...` | PASS |
| Pub mode | `fvm dart analyze utility tool/mc_arch_check`; `fvm dart format --set-exit-if-changed utility tool/mc_arch_check spike` | No issues; 0 of 85 files changed |
| Pub-mode tests | `fvm dart test` in each package | prelude +21, di +15, analysis +6, arch_check +12 |
| Coverage (ADR-0010, 90 %) | `dart test --coverage` + `coverage:format_coverage --report-on=lib` | `mc_prelude` 100 % (52/52). `mc_di` 93.6 % (44/47): the uncovered lines are the concurrent-init guard and `RootImport.toString`. |
| Lockfiles | `fvm dart pub get --enforce-lockfile` | PASS |
| `mc_arch_check` on the Verifier's fixtures and on the real repo | `bazel run //tool/mc_arch_check:bin -- <fixture>` for each fixture (`verifier/make_fixtures.py`, output in `verifier/mc_arch_check-verifier-fixtures.log`) | Every violating fixture exits 1, naming the edge or symbol. The no-false-positive fixture `okrel` and the real repo exit 0. |
| Lint gate applies `mc_analysis` (round 1) | temporary violating file + `build --config=lint` | Fails as expected. Re-run not needed: `//:options` is unchanged. |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0017-AC1 | feature→feature and utility→feature fail, naming the edge | `arch_check_test.dart` `T-0017-AC1 …` (4, including the new conditional-import test) | Yes. **My fixtures** all exit 1, naming the edge: `ff` (nested domain, double-quoted multi-line `show`), `ffpub` (pubspec-only dev dep), `uf` (utility→feature from `test/`), and the new `cond`, a conditional-import alternative `if (dart.library.io) 'package:b_cond/b_cond.dart'`. | PASS |
| T-0017-AC2 | `package:x/src/…` from another package fails as barrel-only | same file, `T-0017-AC2 …` (3) | Yes. **My fixtures** all exit 1 with `[barrel-only]`: `src`, `srcexp` (a barrel re-exporting another package's `src/`), a `src/` URI inside a conditional alternative (`cond`), and the relative path out of the package (`src2`), which was missed in round 1. | PASS |
| T-0017-AC3 | each enabled rule reports on its fixture; README lists sources | `lints_test.dart` `T-0017-AC3 …` (6) | Yes. There are now 21 rules (with `unawaited_futures` back, and a fixture for it). A sentinel file proves the analyzer really ran. A new test shows that a hand-written `feature/x/test/foo_test.dart` is linted while the generated `test/feature/*_test.dart` is excluded. The README records the narrowed exclude and its reason. Mutation check (round 1): a clean fixture fails the test. | PASS |
| T-0017-AC4 | barrel exporting a page, bloc or DI initializer fails naming the symbol (R4); route library importing a feature barrel fails (R15) | same file, `T-0017-AC4 …` (5) | Yes, and every round-1 bypass is now caught. **My fixtures:** <ul><li>`barrel3` (relative `export 'src/…_bloc.dart' show ComicsYBloc;`, a DI initializer and a page): exits 1, naming `ComicsYBloc`, `ComicsYDIInitializer` and the page file.</li><li>`wild` (wildcard `package:` and relative exports): exits 1. Every export without `show` is a violation, and the forbidden classes the file declares are listed (`ComicsWBloc, ComicsWPage`).</li><li>`rtget`: the `RouteTargets` getters `CharsPage get page` and `Widget? get maybe` are flagged, while `CharsFlow get chars` and `CharsFlow? optionalFlow()` are accepted.</li><li>`r15` (route library in a nested wiring): exits 1.</li><li>`okrel` (relative `show` exports of a flow and a navigator): exits 0, so there is no false positive.</li></ul> | PASS |
| T-0017-AC5 | every `Result` member tested; `fromAsync` over an `Error` and `guard` over a `TypeError` keep the message | `result_test.dart` `T-0017-AC5 …` (21) | Yes. New since round 1: `fromAsync`, `fromAction` and `guard` now turn **any** thrown object into a failure (tested with `throw 'a string'` and `throw 42`), and `==` compares runtime types, so `Success<int,String>(1) != Success<int,int>(1)` (tested). | PASS |
| T-0017-AC6 | ordered init, nothing published on throw, retry registers once | `di_container_test.dart` `T-0017-AC6 …` (4) | Yes. Unchanged since round 1. | PASS |
| T-0017-AC7 | `RootImport` resolves the root singleton; child-only types invisible at root; reset isolates; production never resets | same file, `T-0017-AC7 …` (11) | Yes. New since round 1: <ul><li>`RootImport` forwards both factory parameters (`sut<Counted>(parameter: 7).id == 7`).</li><li>`resetDIContainer()` during an in-flight init throws a `StateError`, and the init still publishes.</li><li>The forwarder reads the current root on every resolve, so a child follows a reset and re-init (tested).</li></ul> | PASS |
| T-0017-AC8 | merged tree passes `test` with the aspect; `mc_arch_check` passes on the repo | gates above | Yes | PASS |

## Round-1 issues: status
1. **Major: R4 bypassed by relative exports. Fixed.** The parser is `package:analyzer`, and relative URIs are resolved against the package (`barrel3`, `wild`, `src2` and `cond` above).
2. **Minor: relative cross-package import escapes. Fixed** (`src2`).
3. **Minor: a hung init blocks Retry. Not fixed here, but recorded.**
   - The task file records it as a follow-up for the app-shell task (BootBloc needs a timeout or cancellation story).
   - `resetDIContainer` now refuses to run during an in-flight init, which is the safe choice.
4. **Minor: `RootImport` dropped factory params. Fixed.**
5. **Minor: `resetDIContainer` is public. Mitigated**: it throws during an in-flight init. It is still exported without `@visibleForTesting`. I accept that, because adding `package:meta` for one annotation isn't worth it.
6. **Minor: root changes, F-0013 and `analyzer`. Fixed or recorded.**
   - F-0013 item 1 now says `unnecessary_await_in_return` is "deprecated but still reports".
   - `unawaited_futures` is restored. Dropping `prefer_const_constructors` and `prefer_final_locals` is recorded in the README and the task file.
   - The `tool/loc` reformat is reverted (no diff against `main`).
   - The `MODULE.bazel.lock` regeneration is recorded in the task file.
   - `analyzer` is now a real, used dependency (`dependencies`, and `deps` in `BUILD.bazel`).

## Tide / plan 01 conformance
- **Layout:** each package has `BUILD.bazel`, `pubspec.yaml`, a one-line `analysis_options.yaml`, a barrel and `lib/src/`. `publish_to: none`, `version: 0.1.0`, `resolution: workspace` and `sdk: ^3.13.0` are set. There are no mixins in `mc_prelude` or `mc_di`. This conforms.
- **`mc_analysis`:** Tide's 22 rules minus two, with the reasons recorded and confirmed by me on Dart 3.13.5 in round 1. Additions: `strict-inference` (D-06) and `unawaited_futures`, which is recorded as a non-Tide addition.
- **BDD exclude:** Tide's `**/feature**/*_test.dart` is narrowed to `**/test/feature/*_test.dart`. This is a justified deviation: with our `feature/` folder, Tide's glob would exclude every feature test.
- **`Result`:** Tide's API plus D-07. Catching every throwable goes beyond Tide (which caught only `Exception` and `Error`). It is consistent with D-07's intent.
- **`mc_di`:** Tide's `tide_di` surface plus child containers and `RootImport` (D-17, R17).
- **Remaining cosmetic deviations** (not blocking):
  - `mc_analysis: any` instead of a `path:` dev dependency. The workspace resolves it to the member.
  - The utility barrels don't use `show`. D-05 requires `show` only for feature barrels, which `mc_arch_check` now enforces.

## Hygiene
- **Generated files:** none committed (no `.dart_tool`, `bazel-*`, `*.g.dart`, `*.freezed.dart`, `*.config.dart` or package config).
- **Root changes against `main`:** `pubspec.yaml`, `pubspec.lock` (additions only), `BUILD.bazel`, `analysis_options.yaml`, `MODULE.bazel.lock` and the three `spike/hello` import lines. All of them are listed in the task file.

## Test-integrity audit
- Tests deleted, skipped or weakened: none. Fixture barrels were changed from wildcard to `show` exports to match the stricter R4 rule (`feature_to_feature`, `route_imports_feature`, `src_import`, `utility_to_feature`). That is a needed consequence, not a weakening.
- Lint suppressions added: none in code. The only excludes are the fixture directories and the generated-output globs.
- Golden files: none.

## Issues found (this round)
None blocking.
- **(note)** `_declaredTypes` lists only classes when it names the forbidden symbols of a wildcard export. That is harmless: a wildcard export is already a violation on its own.
- **(note)** `mc_arch_check` doesn't yet enforce the app-layer rows of plan 01 §1 (`app_core` → feature, wiring → wiring). They are outside T-0017's ACs. The TL should make sure a later task owns them.

## Notes for the Tech Lead
- Ready to merge from the Verifier's side.
- The hung-init / Retry story stays a follow-up for the app-shell task (the task file records it).
- Evidence:
  - `verifier/make_fixtures.py`: my fixtures, including the round-2 cases `wild`, `cond`, `rtget` and `okrel`.
  - `verifier/mc_arch_check-verifier-fixtures.log`: CLI output and exit code at `873500c`.
  - `verifier/bazel-gates.log`.
