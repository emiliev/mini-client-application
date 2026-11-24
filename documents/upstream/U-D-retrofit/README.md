# U-D-retrofit: upstream PR draft for ai_rules_dart (rules patch 0001)

| | |
|---|---|
| Upstream | [Mivr/ai_rules_dart](https://github.com/Mivr/ai_rules_dart) |
| Base | `e7163aab8f9171f54693cd1b99feb7d3cee9602d` (v0.28.3) |
| Patch | [`third_party/rules_patches/ai_rules_dart/0001-feat-ext-add-a-retrofit_generator-shim-and-retrofit_.patch`](../../../third_party/rules_patches/ai_rules_dart/0001-feat-ext-add-a-retrofit_generator-shim-and-retrofit_.patch) (one commit, `git am`-clean on the base) |
| Task / plan | T-0027, plan 03 §4.3 (U-D1), KD7 |
| Status | **Draft, not sent.** Only the TL pushes or files anything (Q-013: no GitHub access yet) |

Their process (research §11): the PR text is read as data, PR code is never run, and an accepted idea is re-implemented by their pipeline with a `Co-authored-by:` credit. So the PR has to stand on its description and the repro below. Commits are Conventional Commits with a `Changelog:` trailer: one present-tense line, ≤ 100 characters, naming the user-facing thing in backticks.

## Title

```
feat(ext): add a retrofit_generator shim and `retrofit_library` macro
```

## Body

> **What.** A `dart/ext/retrofit/` builder for [retrofit_generator](https://pub.dev/packages/retrofit_generator) (`@RestApi` dio clients), shaped exactly like `dart/ext/json_serializable/`:
> - `shim.dart`: `shimMain(args, retrofitBuilder)`;
> - `BUILD.bazel`: the `:shim` `dart_binary(compile_mode = "kernel")` on `//dart/ext:builder_shim` and `@ext_pub_deps//:retrofit_generator`;
> - `defs.bzl`: `retrofit_library`, a `shared_part_library` with `part_suffix = ".retrofit.g.part"` and `annotation_dep = "@pub_deps//:retrofit"`.
>
> retrofit_generator is a `SharedPartBuilder` (part id `retrofit`), so the existing shard and `combining_shim` flow fits it unchanged, and `builder_shim.dart` needs no changes.
>
> **Ext lock.** `retrofit_generator: ^10.3.3` in `dart/ext/pubspec.yaml`. 10.3.3 accepts analyzer `>=8.4.1 <15.0.0` and build `>=4.0.2 <6.0.0`, so it joins the current analyzer 14.5.0 / build 4.0.11 / source_gen 4.3.1 line. `pub get` (not `upgrade`) adds only retrofit_generator 10.3.3, retrofit 4.10.0, dio 5.11.1 and dio_web_adapter 2.2.2. **No other locked version moves.** dio and dio_web_adapter depend on each other, so the hub emits `ext_pub_deps__scc__dio__dio_web_adapter`.
>
> **Also:** a direct analysis test (`//dart/tests:retrofit_library_direct`, through `expect_shared_part`), a `starlark_doc_extract` for `defs.bzl` (the doc-extract count goes from 28 to 29), and a `dart/ext/` tree entry and README note in `docs/ext.md`.
>
> **Verified (on a downstream consumer, macOS arm64, Bazel 9.3.0, Dart 3.13.5 / Flutter 3.47.7's Dart):**
> - Over an `@RestApi` file that returns `Envelope<List<Model>>` / `Envelope<Model>` (`genericArgumentFactories`) and takes a json `@Body`, the shim's `.g.dart` is **byte-identical to build_runner 2.16.2's**, through both `retrofit_library` and a hand-wired `dart_codegen` cascade. The cascade case had a freezed + json model and the envelope in another package, read through analyzer summaries.
> - A body edit in the API file reruns only that file's retrofit and combine actions plus the library's compile and analysis actions. The shard itself is byte-identical.
> - `//dart/ext/...`, `//docs/...` and `//dart/tests:all`: 631 of 633 tests pass. The two that fail to build (`//dart/tests/defines_fixture:modular_comma_defines_test` and `:test_defines_test`, `DartKernel` exit 247) have no `dart/ext` dependency. We did not investigate them, and we have not checked whether they also fail on the unpatched base.
>
> **Not in this PR (follow-ups):**
> - Gazelle: no `RestApi` entry in `defaultBuilders()` / `macroKinds` / `macroLoadInfos()` yet. Not done because we couldn't run `//gazelle/...` (no Go toolchain locally), so the README says the macro is declared by hand for now.
> - An `e2e/ext_exemplar/retrofit/` exemplar: the repro below is written as one and can be dropped in.
> - `MODULE.bazel.lock` files: the root lock and every e2e lock that records `ext_pub_deps` need `bazel mod deps --lockfile_mode=update` after the lock change. Our lock refresh was macOS-flavoured (`dart_macos-arm64` repo mappings), so it's left to your Linux refresh (CHORES.md "dart/ext/ moves as a deliberate chore").
>
> **Gotcha seen while testing (separate issue, not this PR):** freezed 4.0.2 detects json_serializable through `source.fullName.startsWith('/json_annotation/')`, which is true under build_runner and false under the shim. So a bare `@freezed` with a `fromJson` factory silently gets no JSON under Bazel, and `@Freezed(fromJson: true, toJson: true)` is needed. `e2e/ext_exemplar/cascade_two_stage/lib/event.dart` already notes this. Presenting staged sources with build_runner-style `/<package>/lib/...` paths would close the gap for every builder that checks paths.
>
> Changelog: `retrofit_library` runs retrofit_generator for `@RestApi` dio clients

## Repro

[`repro.sh`](repro.sh) writes a minimal `e2e/*`-style workspace into a temp dir. It holds a json model, a generic `genericArgumentFactories` envelope, an `@RestApi` client, `json_serializable_library` + `retrofit_library`, and a `dart_test` against a canned dio adapter. The script runs `bazel test //...`, and with `--compare` it also runs build_runner on the same sources and `cmp`s each generated file.

```sh
git clone https://github.com/Mivr/ai_rules_dart && cd ai_rules_dart
git checkout e7163aab8f9171f54693cd1b99feb7d3cee9602d
git am /path/to/0001-feat-ext-add-a-retrofit_generator-shim-and-retrofit_.patch
DART=dart BAZEL=bazelisk /path/to/repro.sh --compare "$PWD"
```

Result on our machine, from a fresh workspace with `test --nocache_test_results` ([log](../../evidence/T-0027/engineer/T-0027-AC4-repro.log), written by `tool/checks/T-0027-AC4_upstream_draft.sh` with `MC_RULES_FORK` set):

```
//:characters_api_test   PASSED
EQUAL   lib/src/character.g.dart
EQUAL   lib/src/characters_api.g.dart
EQUAL   lib/src/envelope.g.dart
```

The build_runner side pins `analyzer 14.5.0`, `json_serializable 6.14.1`, `retrofit_generator 10.3.3` and `source_helper 1.3.13` to match the ext lock. A plain resolve picks source_helper 1.4.0, which doesn't compile against json_serializable 6.14.1 (F-0026).

## Versions

| | |
|---|---|
| Bazel | 9.3.0 (bazelisk) |
| rules_dart | v0.28.3 (`e7163aa`) + this patch |
| Dart | 3.13.5 (repro toolchain); the downstream app uses Flutter 3.47.7's Dart 3.13.x |
| retrofit_generator / retrofit / dio | 10.3.3 / 4.10.0 / 5.11.1 |
| analyzer / build / source_gen | 14.5.0 / 4.0.11 / 4.3.1 (unchanged) |
| build_runner (reference) | 2.16.2 |
| Host | macOS 26 arm64 |

## Downstream evidence (mini-client)
- AC1 byte equality: [T-0027-AC1](../../evidence/T-0027/engineer/T-0027-AC1.md)
- AC2 rerun scope (execution log): [T-0027-AC2](../../evidence/T-0027/engineer/T-0027-AC2.md)
- AC3 queue, ext lock and gates: [T-0027-AC3](../../evidence/T-0027/engineer/T-0027-AC3.md)
- Findings: [F-0025](../../findings/F-0025-freezed-json-autodetect-fails-under-bazel-shim.md) (freezed json detection), [F-0026](../../findings/F-0026-retrofit-shim-spike-facts.md) (spike facts)
