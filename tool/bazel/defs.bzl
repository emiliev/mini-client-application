"""mini-client macros over rules_dart / rules_flutter (plan 03 KD5).

`mcgen buildgen` (P2 C4) will emit calls to these; until then BUILD files call
them by hand.
"""

load("@rules_dart//dart/ext/bdd:defs.bzl", "bdd_feature_test", "bdd_suite_main")
load("@rules_flutter//flutter:defs.bzl", "flutter_test")

_TEST_STEPS = "//utility/mc_test_steps"

# The generated Dart that `tool/ide_sync` writes next to the sources for the IDE
# (T-0042). Every `glob()` over `lib/**` in a package with codegen excludes it,
# so a build is the same with and without a sync: Bazel makes its own copies as
# declared outputs, and a synced file in `srcs` would be a second file for the
# same path. Mirrors the root .gitignore; `tool/checks/T-0042-AC4_safety.sh`
# proves it (a new package whose glob misses this fails that check).
MC_GENERATED_DART = [
    "**/*.g.dart",
    "**/*.freezed.dart",
    "lib/src/di/*.config.dart",
    "lib/src/l10n/*_l10n*.dart",
]

# The generated test's imports (bdd_widget_test `customHeaders`): every
# scenario runs as `mcTestWidgets`, which moves `T-XXXX-ACn` / `MC-...` tags
# into the test name (plan 05 KD4).
_BDD_CONFIG = {
    "testMethodName": "mcTestWidgets",
    "customHeaders": [
        "import 'package:flutter_test/flutter_test.dart';",
        "import 'package:mc_test_utils/mc_test_utils.dart';",
    ],
    "dataTableImport": "package:mc_test_steps/mc_test_steps.dart",
}

def mc_bdd_tests(
        name,
        lib,
        package_name,
        features,
        steps = [],
        setup = None,
        deps = [],
        data = [],
        language_version = "3.13",
        size = "medium",
        shard_count = None,
        tags = [],
        **kwargs):
    """One aggregated BDD test target for a package (plan 05 §5.2, KD6).

    Expands to one generation action per `.feature` (`<stem>_test.dart` in
    bazel-bin; a missing or shadowed step fails the build, naming it), one
    generated entry file (`<name>_main.dart`) that runs them all, and one
    `flutter_test` named `name`.

    Args:
        name: The test target, by convention `bdd_test`.
        lib: The package's library target.
        package_name: The Dart package name.
        features: The `.feature` files (`glob(["test/feature/*.feature"])`).
        steps: Hand-written step and util files (`test/feature/step/*.dart`,
            `test/feature/util/*.dart`). Only files under `step/` next to a
            feature resolve steps.
        setup: Optional Dart file under `test/feature/` with
            `void bddSetUpAll()`, run once in `setUpAll` (fixture sets).
        deps: Extra deps of the step files.
        data: Extra runfiles (fixture assets). The DS fonts are always added.
        language_version: The package's language version.
        size: Test size.
        shard_count: Optional shard count.
        tags: Extra test tags; `bdd` is always added.
        **kwargs: Passed to `flutter_test`.
    """
    if not features:
        fail("mc_bdd_tests(name = %r): `features` is empty; a package without " % name +
             "`.feature` files has no BDD test target.")
    generated = []
    seen = {}
    for feature in features:
        if not feature.endswith(".feature"):
            fail("mc_bdd_tests: %s is not a .feature file" % feature)
        gen = "_%s_gen_%s" % (name, feature[:-len(".feature")].replace("/", "_"))
        if gen in seen:
            fail(("mc_bdd_tests: %s and %s both map to the target name %s " +
                  "(`/` becomes `_`); rename one of them.") % (seen[gen], feature, gen))
        seen[gen] = feature
        bdd_feature_test(
            name = gen,
            testonly = True,
            src = feature,
            package_name = package_name,
            language_version = language_version,
            steps = steps,
            step_indexes = [_TEST_STEPS + ":step_index"],
            config = _BDD_CONFIG,
        )
        generated.append(":" + gen)

    main_dir = features[0].rpartition("/")[0]
    bdd_suite_main(
        name = name + "_main",
        testonly = True,
        out = ("%s/%s_main.dart" % (main_dir, name)) if main_dir else ("%s_main.dart" % name),
        tests = generated,
        setup = setup,
    )

    flutter_test(
        name = name,
        size = size,
        shard_count = shard_count,
        srcs = generated + steps + ([setup] if setup and setup not in steps else []),
        main = ":" + name + "_main",
        package_name = package_name,
        language_version = language_version,
        data = ["//utility/mc_ds_theme:fonts"] + data,
        tags = ["bdd"] + tags,
        deps = [
            lib,
            _TEST_STEPS,
            "//utility/mc_test_utils",
            "@pub_deps//:flutter",
            "@pub_deps//:flutter_test",
        ] + deps,
        **kwargs
    )
