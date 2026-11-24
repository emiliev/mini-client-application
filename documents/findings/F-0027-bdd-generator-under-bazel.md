# F-0027: BDD generation under Bazel: what works, and how it differs from plan 03 §4.4

- **Date:** 2026-11-24
- **Author:** crew: Engineer (T-0029)
- **Type:** Spike
- **Related:** T-0029 (AC1 to AC6), plan 03 §4.4, X2, X4, KD7, plan 05 §3, §5.2, KD4, KD6, R28, V2-07, F-0011

## Summary
Generating `.feature` → `_test.dart` under Bazel works in one pass, so the R28 build_runner fallback is not needed. The generator is a fork patch (`0003-ext-bdd-generator.patch`, `dart/ext/bdd/`). It reuses bdd_widget_test **3.0.5**'s `lib/src` parser and emitter (`parseFeatureFile`, `StepFile.create`, `generateFeatureDart`); it skips the stock `FeatureFile` wrapper, so it can rewrite the model before emitting. The macro `mc_bdd_tests` builds one `:bdd_test` per package. JUnit case names carry the AC IDs, for example `greeting_browse Greeting The greeting is shown [T-0001-AC1]`. The R28 fallback stays traceable: stock bdd_widget_test 3.0.5 run by build_runner with `testMethodName: mcTestWidgets` passes `tags: ['T-0001-AC1', 'smoke']`, and the names come out the same.

## Facts and deviations from the plan
1. **Not a builder shim.** `shimMain` only runs `package:build` Builders and needs the analyzer. The generator is a plain `dart_binary`. It speaks the shim CLI contract (`--input`, `--input-asset`, `--output`, `--package`, `--root-language-version`, `--config`, `--dep`, `--part`) and the proto worker protocol through `bazel_worker`, like `combining_shim`. `dart_sqlcodegen` drives it unchanged (`supports-workers`, mnemonic `DartSqlCodegen`). No analysis context is built per request, so X-10/H-CODEGEN-COST does not apply to BDD.
2. **Step indexes travel as `--part`, not `asset_deps`.** `asset_deps` goes through `asset_path_for`, which fails for a file outside the consuming Dart package. `mc_test_steps:step_index` (a `bdd_step_index` rule: `{"import": "package:mc_test_steps/mc_test_steps.dart", "steps": [...]}`) is therefore passed in `parts`. Local steps use `asset_deps` and resolve only under `./step` next to the feature.
3. **Shared steps import the barrel.** bdd_widget_test only knows file-path imports, and its `externalSteps` matches by *substring* of the file name (`'i_see.dart'` also matches `ai_see.dart`). The generator therefore resolves each step itself: exact file-name match, local first. A local step with the name of a shared one is an error (plan 05 §3.2 rule 4). Shared steps are emitted through a placeholder import that is rewritten to the index URI and deduplicated.
4. **Tag pre-pass.** Stock bdd_widget_test puts tags written above `Feature:` into a library-level `@Tags([...])`. That annotation is lost once an aggregator imports the file. The generator moves those tags onto every scenario, so they reach `mcTestWidgets` as `tags:` and, for `T-…`/`MC-…`, the name. `@skip` and `@wip` are refused (`forbiddenTags`).
5. **Data tables.** The stock emitter imports `package:bdd_widget_test/data_table.dart as bdd`. The generator rewrites that one line to `dataTableImport` (`package:mc_test_steps/mc_test_steps.dart`), whose `DataTable` has the same `const DataTable(List<List<...>>)` shape. Tests have no runtime dependency on bdd_widget_test.
6. **The analyzer is in the tool closure only.** `cquery 'deps(:bdd_test)' --notool_deps` (2,952 targets) has no analyzer, `build` or bdd_widget_test. With tool deps, analyzer appears only in the exec configuration, through the generator → `dart_style` → `analyzer` (bdd_widget_test also depends on `build`). Any generator that formats its output has this, the stock shims included. AC4 is checked on the runtime closure, and the evidence shows both.
7. **S5 answered: yes.** A generated `main` in bazel-bin imports source-tree files by relative path (`import './step/x.dart'`, `import 'util/greeting_env.dart'`) under `flutter_test`, through rules_flutter's multi-root `org-dartlang-app` scheme. Generated files are not `is_source`, so the `dart_analyze` and `dart_format` aspects skip them with no exclusion needed.
8. **Fixture registration.** A generated test has no hook for `McFixtureSets.register`. `mc_bdd_tests(setup = "test/feature/util/<x>.dart")` makes the aggregator call that file's `bddSetUpAll()` in `setUpAll`. The stock fallback needs the same kind of entry file (the AC5 check writes one).
9. **Output format.** The generator formats at the package's `--root-language-version` (tall style at 3.13, F-0011), and the scaffold formats stubs at the package's `sdk:` floor. The stock Builder always uses the short style. Imports are re-sorted into `directives_ordering` order after the rewrites (a scaffolded data-table stub otherwise failed the package's lint gate).
12. **One source of truth for shared steps.** `mc_test_steps:step_index` lists only files in a group folder (`lib/src/<group>/**`), so helpers directly in `lib/src/` (`data_table.dart`) are never steps. Both the generator (`--part`) and `//tool/bdd:scaffold` (`--step-index=$(rootpath ...)`) read that index, and the AC5 check lists the same set.
13. **The fork's own gates are stricter than ours.** The consumer's lint aspect skips external repos, so `dart/ext/bdd` must also pass the fork's `bazel test` (its `.bazelrc` turns on `dart_analyze` and `dart_format`, with infos fatal). The fork formats at the target's `language_version` (3.11). Code is written so that 3.11 and the latest style agree. The parser and emitter imports carry `// ignore: implementation_imports` (as `dart/ext/lib/builder_shim.dart` does). Changing `dart/ext/pubspec.lock` also changes the fork's `MODULE.bazel.lock` (it runs with `--lockfile_mode=error`), so the patch carries it.
10. **The stock fallback has two gaps** (relevant only if R28 is ever used). (a) Shared steps must be listed as `externalSteps` by `package:mc_test_steps/src/...` path, because it matches file names. (b) Data tables pass `package:bdd_widget_test`'s `DataTable`, which is not `mc_test_steps`' type, so table steps would need a shim. Neither gap affects traceability.
11. **Stacking with 0001/0002.** `0003` applies strictly on the pin, but not on top of 0001: 0001 (retrofit, which also brings `dio`) changes the context lines of `dart/ext/pubspec.yaml` and `dart/ext/pubspec.lock`, and 0003 also carries the fork's own `MODULE.bazel.lock`. **0003 is rebased onto 0001+0002 at merge time**: re-export it from a fork on top of them and re-resolve `dart/ext/pubspec.lock` and `MODULE.bazel.lock` (`bazel mod deps --lockfile_mode=update`) rather than hand-merging them; then `rules_fork.sh check`.

## Evidence
`documents/evidence/T-0029/engineer/`:
- `T-0029-AC1_junit_names.md` and `T-0029-AC1_bdd_test.xml`;
- `generated/*.dart`, the bazel-bin outputs;
- `T-0029-AC2_missing_step.md`;
- `T-0029-AC3_scaffold.md`;
- `T-0029-AC4_no_analyzer.md`, with `T-0029-AC4_cquery_notool_deps.txt` and `T-0029-AC4_tool_closure_generator_targets.txt`;
- `T-0029-AC5_stock_fallback.md`, with `T-0029-AC5_fallback_junit.xml` and `T-0029-AC5_stock_greeting_browse_test.dart`.

## Implications / actions
- R28's BDD fallback is not triggered. `tool/build_runner_overlay` carries bdd_widget_test 3.0.5 only for the AC5 check.
- `mcgen buildgen` should emit `mc_bdd_tests(features = glob(["test/feature/*.feature"]), steps = glob(["test/feature/step/**/*.dart", "test/feature/util/*.dart"]), setup = ...)`.
- P5-02 (the full step library) adds files under `utility/mc_test_steps/lib/src/<group>/` plus barrel exports; `:step_index` picks them up by glob.
- Upstream: `documents/upstream/U-D-bdd/`.
