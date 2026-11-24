# U-D-bdd (plan U-D3): `ext: hermetic bdd_widget_test generator (dart/ext/bdd)`

Upstream PR draft for [Mivr/ai_rules_dart](https://github.com/Mivr/ai_rules_dart), not filed yet: there is no GitHub access for upstream ([Q-013](../../open-questions.md#q-013)). The change itself is our patch [`third_party/rules_patches/ai_rules_dart/0003-ext-bdd-generator.patch`](../../../third_party/rules_patches/ai_rules_dart/0003-ext-bdd-generator.patch), one commit on pin `e7163aa` (v0.28.3). Background: [F-0027](../../findings/F-0027-bdd-generator-under-bazel.md), [T-0029](../../tasks/T-0029-bdd-generator.md).

## PR title
ext: generate bdd_widget_test widget tests from `.feature` files (`dart/ext/bdd`)

## PR body (draft)

**Problem.** [bdd_widget_test](https://pub.dev/packages/bdd_widget_test) is the common way to write Gherkin widget tests in Flutter. You can't run its `FeatureBuilder` under rules_dart's shim:
- it writes step stubs and hook files straight to disk, outside the declared outputs;
- it reads `bdd_options.yaml` and `pubspec.yaml` from the source tree;
- 3.1.x needs `build ^5`, while the ext lock has build 4.

**Change.**
- `dart/ext/pubspec.{yaml,lock}`: add `bdd_widget_test: 3.0.5`, pinned exactly because we import its `lib/src`. It brings in `cucumber_gherkin` 42.0.1, `cucumber_messages` 34.2.1, `diacritic` 0.1.6 and `characters` 1.4.1, and no existing version changes.
- `dart/ext/bdd/lib/bdd_generator.dart`: reuses bdd_widget_test's parser and emitter (`parseFeatureFile`, `StepFile.create`, `generateFeatureDart`), so the output is the stock dialect. It then adds:
  - **hermeticity:** it sees only staged step files (`--dep`) and step indexes (`--part`, a `*.bdd_steps.json`);
  - **missing steps:** a missing step is a build error that names each step, its file and its function, and never writes a stub;
  - **shadowing:** a local step with the name of an indexed shared step is an error;
  - **exact matching:** steps are matched by exact file name (stock `externalSteps` matches by substring);
  - **tags:** tags written above `Feature:` are moved onto every scenario, so they survive aggregation (a library-level `@Tags` does not), and `@skip`/`@wip` are refused (`forbiddenTags`);
  - **data tables:** `dataTableImport` points them at another `DataTable` type, so tests need no runtime bdd_widget_test;
  - **formatting:** the output is formatted at `--root-language-version`;
  - **options:** those that need undeclared files (`addHooks`, `include`, `externalSteps`) are rejected with a message.
- `dart/ext/bdd/bin/generator.dart`: the shim CLI contract plus the proto worker loop (like `combining_shim`). It doesn't use `package:build` or build an analysis context per request.
- `dart/ext/bdd/defs.bzl`:
  - `bdd_step_index`: the step files of a shared library and the URI that exports them;
  - `bdd_feature_test`: one `dart_sqlcodegen` per `.feature`, writing `<stem>_test.dart`;
  - `bdd_suite_main`: one entry file that runs every generated test of a package in a `group`, with an optional `setUpAll` hook.
- `dart/ext/bdd/lib/scaffold.dart`: the non-hermetic stub writer, meant for a consumer's `bazel run` tool. It reads the same step indexes as the build, scans the top-level `.feature` files of a folder (what `glob(["test/feature/*.feature"])` gives), writes the stock stub format at the package's language version, and never touches existing files.
- `dart/ext/bdd/test/bdd_generator_test.dart`: 15 tests covering tags, imports (and their order), data tables, missing, shadowed, duplicate and out-of-folder steps, `../` step folders, forbidden tags, rejected options and bad config or index JSON, stubs and the index format.
- `MODULE.bazel.lock`: updated for the new ext lock entries.

**Testing.**
- `bazel test //dart/ext/bdd:all` passes in the fork itself (its `.bazelrc`: `dart_analyze` and `dart_format` on), and `dart format --set-exit-if-changed dart/ext/bdd` is clean.
- Downstream (mini-client), `//spike/bdd_sample:bdd_test` runs two features, one of them with a data table, in one `flutter_test`. Its JUnit names carry the scenario tags.
- A negative fixture fails the build, naming 2 missing steps, and the source tree stays byte-identical.

**Notes for the reviewer.**
- Why not a builder shim: `shimMain` only runs `package:build` Builders, and this generator doesn't need the resolver.
- `--part` for step indexes: `asset_deps` refuses files outside the consuming package (`asset_path_for`). A first-class `step_indexes` attribute on `dart_sqlcodegen`, or a cross-package `asset_deps`, would be cleaner. That is open for discussion.
- The generator closure contains `analyzer` (through `dart_style` and `build`), in the exec configuration only.

## Before filing
- Add a `docs/ext.md` section; it was left out of the patch to avoid conflicts with the retrofit and injectable patches in the same queue.
- Add an `e2e/` exemplar with a `flutter_test` over a generated suite. Upstream e2e may need a Flutter-free variant (`testMethodName: test`).
- Rebase onto upstream `main` and regenerate `dart/ext/pubspec.lock` and `MODULE.bazel.lock`. In our queue, 0003 is rebased onto 0001+0002 at merge time (F-0027 fact 11).
