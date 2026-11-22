# ai_rules_dart: research notes (T-0013)

| Field | Value |
| --- | --- |
| Upstream | https://github.com/Mivr/ai_rules_dart |
| Snapshot read | shallow clone, HEAD `be4e99f520cd9bd9e56cc0bd680750d34308608c` (2026-11-16), 60 commits deep |
| Method | Read-only: files, grep and `git log`. Nothing from the repo was built or run. |
| Sister repo | `ai_rules_flutter` (to be covered separately) |

All paths are relative to the repo root. **(inferred)** marks a conclusion drawn from reading code, not one the project states.

---

## 1. Summary and maturity

`ai_rules_dart` is a Bazel rule set for Dart: SDK toolchains, `dart_library` / `dart_binary` / `dart_test`, pub.dev integration, `build_runner`-free code generation, an analyzer/format aspect, and a Gazelle plugin. It was built to be extended by `rules_flutter` (`docs/ARCHITECTURE.md:9`, `:30` "DartInfo contains zero Flutter concepts"). It continues `aran/rules_dart` (README.md:11-12, `:885-897`). The README says it is "written, reviewed, tested and released by AI agents" (README.md:1-9). The human owner is @Mivr (`SECURITY.md`, `CONTRIBUTING.md:5`).

| Attribute | Finding | Source |
| --- | --- | --- |
| Module name / repo name | `ai_rules_dart`, `repo_name = "rules_dart"` (labels are `@rules_dart//...`) | `MODULE.bazel:13-17` |
| Version | No `version` in `MODULE.bazel` (patched in at BCR publish). Latest tag in the clone is **v0.28.3** (`e7163aa`, 2026-11-15). v0.28.2 is `2afe695`. The README install snippet is stale at 0.18.0. | `MODULE.bazel:3-8`, `git tag`, README.md:24-29 |
| Bazel | `.bazelversion` = **9.3.0**. `bazel_compatibility = [">=9.0.0"]`. CI's `e2e-floor` job re-runs the e2e workspaces on 9.0.0. | `.bazelversion`, `MODULE.bazel:16`, `.github/workflows/ci.yaml:681-692` |
| bzlmod vs WORKSPACE | **bzlmod only.** No WORKSPACE path. | `docs/adr/0003-bazel-9-and-bzlmod-only.md` |
| Host platforms | macos-arm64, macos-x64, linux-x64, linux-arm64, windows-x64. Cross-only targets: linux-riscv64, linux-arm. **macOS arm64 is a supported host.** | `docs/ARCHITECTURE.md:65`, `dart/private/toolchains_repo.bzl:35-67,119-123` |
| macOS CI depth | Push CI runs on Linux and Windows. macOS runs as one Full job over a subset (114 of the root's 1,103 tests) plus a nightly `mac-smoke`. | commit `623b538`, `.github/workflows/ci.yaml:798-805`, `full.yaml:227-231` |
| Licence | Apache-2.0 | `LICENSE` |
| BCR | `publish.yaml` opens **draft** BCR PRs through `publish-to-bcr`. The README installs with `archive_override` from a GitHub release. Whether the module is live on BCR is unclear **(inferred)**. | `.github/workflows/publish.yaml`, README.md:21-36, `.bcr/` |
| Activity | Very high. 60 commits from 2026-11-12 to 11-16. v0.8.0 on 2026-10-15, v0.28.3 on 2026-11-15, so about 20 minor releases in a month. `auto-release.yaml` now tags each green `main` commit that carries a user-facing changelog trailer. Authors in the window: "Mihail Vratchanski" 37 (with `Agent:` / `Work-Item:` trailers), "Claude" 15, "agent" 8. | `git log`, `ai-docs/performance/README.md:40-44`, commit `2fb6a6e` |
| Size | 2,399 files. About 34k lines of `.bzl` under `dart/`. Large Dart tools, e.g. `dart/private/tools/kernel_module.dart` at 5,596 lines. | `wc` |

**Maturity verdict (inferred):** the engineering is unusually rigorous (hermeticity, reproducibility and action-golden gates). The churn is extreme: a minor bump every one to two days, with breaking changes allowed under 0.x. Docs drift in places. `docs/ext.md:240,422` says `package:analyzer` 10.x, but the pin is 14.5.0 (`dart/ext/pubspec.lock`, README.md:759). We should pin a commit and upgrade on purpose.

---

## 2. Public API

### 2.1 Rules and macros (`load("@rules_dart//dart:defs.bzl", ...)`, `dart/defs.bzl:1-63`)

| Rule | Purpose | Key attributes | Provides |
| --- | --- | --- | --- |
| `dart_library` | Collects sources and propagates deps. **Does not compile.** Kernel modules are built on demand by an aspect. | `srcs`, `deps`, `resources`, `data`, `srcs_dir`, `package_name`, `language_version`, `version`, `code_assets`, `link_hook`, `members` | `DartInfo`, `DartKernelInfo` (via aspect) |
| `dart_package_member` | A target that adds files to a package another target owns | `srcs`, `resources`, `data`, `package_name`, `language_version` | `DartInfo` |
| `dart_package_metadata` | States `package_name` and `language_version` once; rules point at it with `package = ":pkg"` | `package_name`, `language_version` | `DartPackageMetadataInfo` |
| `dart_source_set` | Copies hand-written and generated sources into one directory | `srcs`, `root_paths`, `replace_prefixes` | `DartInfo` |
| `dart_binary` | `exe` (default), `aot-snapshot`, `kernel`, `jit-snapshot` | `main`, `srcs`, `deps`, `compile_mode`, `dart_compile_flags`, `defines`, `modular_kernel`, `link_modules`, `split_debug_info`, `record_use`, `code_assets(_from_deps)`, `launcher` | `DartCompileInfo`, `DartAnalyzableInfo`, `DartRecordedUsesInfo` (not `DartInfo`) |
| `dart_test` | Runs a test on the VM. Uses `package:test`'s runner when `@pub//:test` is a direct dep. | `main`, `srcs`, `deps`, `defines`, `include_tags`, `exclude_tags`, `env`, `env_inherit`, `data`, `code_assets(_from_deps)`, plus `shard_count` / `size` | `DartAnalyzableInfo`, `InstrumentedFilesInfo` |
| `dart_js_binary` / `dart_wasm_binary` | `dart compile js` / `wasm` | `main`, `srcs`, `deps`, `dart_compile_flags`, `defines` | |
| `dart_codegen` | Per-file `package:build` Builder run | `src`, `generator_bin` or `generator`, `output_suffixes`, `deps`, `parts`, `config` (JSON), `asset_deps`, `package_config`, `generator_args`, `data` | generated files |
| `dart_aggregate_codegen` | Whole-package Builder (one action over all `srcs`) | `srcs`, `outputs`, `generator_bin` or `generator_script`, `deps`, `asset_deps`, `config` | generated files |
| `dart_sqlcodegen` | Like `dart_codegen` for non-Dart inputs (`.drift`) | as `dart_codegen` | |
| `dart_analysis_options`, `dart_analysis_config` | Declare every `analysis_options.yaml` for the aspect | `src`, `deps`; `options` | `DartAnalysisOptionsInfo` |
| `dart_analysis_test` | Applies the analyze aspect to targets `//...` can't reach | `targets` | |
| `dart_fix`, `dart_format` | `bazel run` source rewriting | `target` | |
| `dart_code_asset` | Binds a native dylib (`cc_shared_library` or prebuilt) to a code-asset id | | `DartCodeAssetInfo` |
| `dart_link_hook` | Runs packages' `hook/link.dart` over recorded uses | `recorded_uses`, `data_assets`, `deps` | `DartDataAssetInfo` |

Builder macros, one per builder, live under `@rules_dart//dart/ext/<builder>:defs.bzl`: `json_serializable_library`, `freezed_library`, `built_value_library`, `mockito_library`, `go_router_library`, `copy_with_library`, `drift_library`, and `stacked_{router,locator,logger,dialog,bottomsheet,form}_library` (`gazelle/dart/builder_registry.go:139-270`). The generic macros `library_builder_library` and `shared_part_library` are in `@rules_dart//dart/ext/_shared:defs.bzl:31,113`.

Test-runner rules `dart_test_kernel` and `dart_test_package` are exported through `dart/utils.bzl:256-257`.

### 2.2 Module extensions

| Extension | Tags | Notes |
| --- | --- | --- |
| `@rules_dart//dart:extensions.bzl%dart` | `toolchain(name = "dart", dart_version)` | The root's request wins even if older. Otherwise the highest requested version wins. Only the root may add names. (`dart/extensions.bzl:1-36`) |
| `@rules_dart//dart/pub:extensions.bzl%pub` | `package(name, version, sha256, deps, package_files)`; `from_lock(name, lock, ignore_hooks, on_version_conflict = "error"\|"upgrade", isolated, workspace_members, package_files)` | `dart/pub/extensions.bzl:23-103,1042-1049` |

### 2.3 Providers, aspects, flags

- Providers (`dart/providers.bzl`): `DartInfo`, `DartPackageInfo`, `DartPackageMetadataInfo`, `DartAnalyzableInfo`, `DartPackageConfigInfo`, `DartCompileInfo`, `DartCodeAssetInfo`, `DartRecordedUsesInfo`, `DartDataAssetInfo`, `DartAnalysisOptionsInfo`, `DartKernelInfo`, `DartImportCheckInfo`. `DartSdkInfo` is in `dart/toolchain.bzl:5`. Contracts are in `docs/ARCHITECTURE.md:13-40`. **`DartInfo` means "valid as a dep"**; executables give only `DartAnalyzableInfo` (`docs/adr/0002`).
- Aspects: `dart_analyze` (`dart/analyze.bzl:28`) and `dart_import_check_aspect` (`dart/import_check.bzl:58`). The kernel module aspect and `dart_info()` constructors for downstream rule sets are exported from `dart/utils.bzl:121-226`. rules_flutter is expected to build `DartInfo` and `DartKernelInfo` through these (`ai-docs/performance/for-rules-flutter.md`).
- Build settings (`dart/BUILD.bazel`): `//dart:modular_kernel` (default True, `:144`), `//dart:analyzer_summaries` (True, `:118`), `//dart:test_runner_snapshot` (True, `:53`), `//dart:analysis_config` (label, `:322`), `//dart:extra_dart_defines` (repeatable, `:32`), `//dart:refused_dart_libraries` (`:41`), `//dart:jit_snapshot_fallback` (False, `:75`), `//dart:jit_snapshot_lock_timeout` (300 s, `:92`). The feature `dart_layering_check` is on by default (`docs/ARCHITECTURE.md:75`).

---

## 3. Toolchain

- **Fetch:** `dart_repositories` downloads `https://storage.googleapis.com/dart-archive/channels/stable/release/{version}/sdk/dartsdk-{platform}-release.zip` and checks it against a pinned SHA-256 from `TOOL_VERSIONS`. It returns `repo_metadata(reproducible = True)`, so the repo contents cache works (`dart/repositories.bzl:47-105`).
- **Pinned versions:** only **3.11.0 to 3.13.5** are in the table (`dart/private/versions.bzl:79-149`). `dart_version` is an `attr.string(values = TOOL_VERSIONS.keys())`, so any other version is refused (`dart/repositories.bzl:33-37`). The default in this repo and its e2e workspaces is **3.13.5** (`MODULE.bazel:91`). Cross `gen_snapshot` and `dartaotruntime` artifacts are pinned separately (`versions.bzl` `CROSS_*`, `docs/ARCHITECTURE.md:83-107`).
- **Toolchain types:** there are two. `//dart:toolchain_type` is target-configured (binaries and tests). `//dart:exec_tools_toolchain_type` is exec-configured (codegen, analyzer, kernel module/link, format) and omits `target_compatible_with`. Codegen and host tools therefore resolve even when the target platform is iOS or Android (`docs/ARCHITECTURE.md:135-145`). This matters for a Flutter graph.
- **SDK subsets:** `DartSdkInfo.compile_files`, `runtime_files` and `analyze_files` keep actions from depending on the whole 642 MB SDK. Test runfiles dropped from 1,073 files / 699 MB to 39 / 282 MB (`ai-docs/performance/plan.md:15,22`). A toolchain from another rule set, such as Flutter's bundled Dart under `bin/cache/dart-sdk`, falls back to the full `tool_files` unless it declares these filegroups (`for-rules-flutter.md`, "DartSdkInfo has two new fields").
- **Hermeticity:** the SDK is pinned by hash. The `dart` extension also AOT-compiles `dart_pub_scanner` at **fetch time** from the host SDK (`dart/extensions.bzl:38-62`), so a repository rule runs `dart compile`. `.bazelrc` uses `--lockfile_mode=error`, and `tools/preset.bazelrc` sets `--nosandbox_default_allow_network`.
- **Kernel tools coupling:** every kernel `.dill` tool must be compiled by the same exec SDK that runs it, checked with `kernel_sdk_mismatch_error` (`docs/ARCHITECTURE.md:141`).

---

## 4. Third-party pub dependencies

| Aspect | Behaviour | Source |
| --- | --- | --- |
| Model | Hub-and-spoke. `pub.from_lock(name = "pub_deps", lock = "//:pubspec.lock")` creates hub `@pub_deps` and one spoke repository per package (`@pub_deps//:path`). Each spoke is a generated `dart_library`. | README.md:256-282 |
| Sources | `hosted` and `git` only. `path`, `sdk` and other sources are **skipped** with one grouped warning. Local packages must be first-party `dart_library` targets or `pub.package()`. | README.md:305-321, ADR 0006 |
| Pinning | Hosted: archive `sha256` from the lock. Empty sha is refused (`plan.md:32`). Git: full 40-hex `resolved-ref`, materialized through a fresh bare repo with host git config scrubbed. | README.md:315-320, `docs/ARCHITECTURE.md:67` |
| Registry | Spokes take a `base_url` (default `https://pub.dev`) and fetch `{base}/packages/{name}/versions/{version}.tar.gz`. A private hosted registry would come from the lock's `description.url` **(inferred)**. | `dart/pub/private/pub_lock_package.bzl:214,266-269` |
| Version resolution | **One version per package across all non-isolated hubs in the whole module graph.** Hub names are global to the extension. `on_version_conflict = "error"` (default) fails when another lock has a higher version; `"upgrade"` takes the higher one. A root `pub.package()` or root lock pin beats dependency declarations, with a NOTE. | `dart/pub/extensions.bzl:49-90`, `docs/pub.md:62-127` |
| Isolation | `isolated = True` gives `<hub>__<pkg>` spokes with their own versions. rules_dart's own generator deps are an isolated hub, `ext_pub_deps`. | `MODULE.bazel:117-127`, README.md:322-339 |
| Cycles | Cyclic pub deps (e.g. `dio` and `dio_web_adapter`) merge into one multi-package `dart_library`. Pubspec dep names are cached as "facts" in `MODULE.bazel.lock` and checked against the real pubspec. | README.md:341-346, `docs/pub.md:1-18`, `docs/ARCHITECTURE.md:67` |
| Security | Every archive is scanned before extraction. Hard links, absolute links and escaping symlinks are refused. | `docs/ARCHITECTURE.md:67` |
| Pub workspaces | `workspace_members = [...]` checks `resolution: workspace`, globs and `pubspec_overrides.yaml`. Members depend on each other through `dart_library` labels, not the lock. | `docs/pub.md:158-208` |
| Build hooks | A package with `hook/build.dart` fails any consuming binary or test unless a `dart_code_asset` replaces it or it is in `ignore_hooks`. Curated replacements exist only for `sqlite3` >= 2.0.0 and `webcrypto` 0.6.1. | `dart/private/common.bzl:1594-1636`, `dart/private/curated_registry.bzl:17-34` |
| Runtime files | Each spoke stages `pubspec.yaml` and `LICENSE*` (`package_files`) in runfiles only, for Flutter plugin discovery. They never become action inputs. | README.md:284-303, `docs/pub.md:20-60` |

**Local path packages** in our 100+ package monorepo: each becomes a hand-written or generated `dart_library` with `package_name` (README.md:62-80, `:491-529`). Strict layering means every imported package must be a **direct** dep (`docs/ARCHITECTURE.md:75`).

---

## 5. Compilation model

### 5.1 Action graph per target type

| Target | Actions (mnemonic) | Granularity | Notes |
| --- | --- | --- | --- |
| `dart_library` | none of its own. Under a consumer that needs modules: **`DartKernel`** (one per library: `.kmod` dir, `.koutline` dir, `index.json`, `.vm_excluded.txt`). Under the analyze aspect: `DartAnalyzerSummary`. Validation: `DartImportCheck`. | per `dart_library`; one kernel per **import SCC** inside it | `dart/private/dart_kernel.bzl:1-42`, `ai-docs/performance/findings.md:121-129` |
| `dart_test` | `DartKernel` for its entry module, against the deps' `.koutline` summaries, then **`DartKernelLink`**, which concatenates the reachable `.kmod` kernels (deps first, entry last) into the test kernel. Optional coverage map. | per test | README.md:136-147, `docs/ARCHITECTURE.md:46-51` |
| `dart_binary(kernel)` | same as `dart_test` (modular) | per binary | |
| `dart_binary(exe/aot-snapshot)` | **whole-program from source by default**: `DartCompile` (`gen_kernel --aot`, then `dart compile`). With `link_modules = True`: modules, link, `gen_kernel --from-dill --aot`, plus `DartLinkCheck`. | per binary | README.md:160-179, `docs/adr/0005`, commits `ddf5d5d`, `59f9cd6` |
| `jit-snapshot` | whole-program kernel, then app-JIT training (`DartJitSnapshot`) at a fixed `/tmp/rules_dart_jit-<key>` path | per binary | `docs/ARCHITECTURE.md:74` |
| `dart_js_binary` / `wasm` | `DartCompileWeb`, whole program | per binary | `docs/ARCHITECTURE.md:50` |

**Frontend:** this is not `frontend_server` and not dartdev in a worker. Modules go through the SDK's `kernel_worker_aot.dart.snapshot`, driven by a wrapper, `kernel_module` (`findings.md:73-75`). Whole-program VM compiles use `gen_kernel` with the stable `org-dartlang-root` filesystem scheme, then `dart compile` (`docs/ARCHITECTURE.md:66`).

**Workers:**

| Mnemonic | Worker type | Detail |
| --- | --- | --- |
| `DartKernel` | **multiplex** + singleplex fallback, cancellation, proto | One `kernel_module` process serves concurrent requests over a pool of **up to CPU-count `kernel_worker` children**, sharing an outline cache. Flags `--reuse-compiler-result --use-incremental-compiler`. (`dart_kernel.bzl:735-760,839-858`, `dart/private/tools/kernel_module.dart:252-255`) |
| `DartKernelLink`, `DartAnalyze`, `DartAnalyzerSummary`, `DartFormat` | singleplex | `dart_kernel.bzl:1072-1080`, `dart_analyze_aspect.bzl:490` |
| `DartCodegen` / `DartAggregateCodegen` / `DartSqlCodegen` | **singleplex only** | `source_gen`'s process-global `rootPackageName` blocks multiplexing (`docs/ext.md:164-168`) |

**Incremental compilation:** inside a warm worker, a small component compiles in 7 to 11 ms, against 42 to 48 ms one-shot. Peak RSS was 409 MB (`findings.md:130-132`). Across builds, the mechanism is Bazel action caching plus outline early cutoff, not a long-lived incremental compiler over the program.

### 5.2 What gets rebuilt

- **Outlines give ABI-style early cutoff.** `.koutline` is a deterministic, body-stripped outline kernel. Dependents compile against outlines with `--input-summary`. A body-only edit should leave the outline byte-identical, so dependents' action keys don't change **(inferred from design)**. The README says: "Editing a leaf library recompiles that library and the dependents that reach its changed outline, not every test" (README.md:142-146). `unused_inputs_list` also lets Bazel drop unread inputs from the key (`dart_kernel.bzl:646-665`).
- **Mixins defeat the cutoff:** any class usable as a mixin (`mixin`, `mixin class`, and every class in a library with language version < 3.0) **keeps its bodies in the outline** (`dart_kernel.bzl:14-16`, `dart/private/tools/dill_outline.dart:1-14`). A body edit there recompiles dependents.
- **SDK-format guard:** the stripper accepts only kernel format **138 (Dart 3.13.x)**. On any other version it logs and **falls back to unstripped bytes** (`dart_kernel.bzl:16-19`, `dill_outline.dart:9-25`). On another SDK there are no outlines and no early cutoff **(inferred)**.
- **Barrel files:** the authors note that a re-exporting `pkg.dart` limits the body-edit win, because every importer of the barrel recompiles (`ai-docs/performance/decisions.md:146-148`).
- **Linking is per test:** every `dart_test` re-links when any reachable `.kmod` changes. That is a cheap concatenation, but it is O(tests reaching the edit).
- **Two kernel variants:** `dart_test` compiles with `dart.vm.product=false` and kernel binaries with `true`. A library used by both is compiled twice (`docs/ARCHITECTURE.md:66`).
- **Measured** on the 30-package bench (4 cores): leaf body edit 15.7 s → 9.2 s, whole compiles re-run 31 → 1, API edit 15.9 s → 8.5 s, clean 23.6 s → 19.0 s (`ai-docs/performance/plan.md:41-58`). Kernel-module phase timing on a 100k LOC, 30-module workspace: an API edit in layer 0 reran **8 modules in a chain of 6**, with 1,426 ms build wall, about 1.0 s of it compile. Platform and outline loading came to ≤ 7.7 % of the flow (commit `efa6e99`).
- **AOT / release (`exe`) stays whole-program**: every body edit recompiles the full program unless `link_modules = True`. Even then the final `gen_kernel --aot` and `gen_snapshot` steps are whole-program (README.md:160-179).

### 5.3 Analyzer actions

The `dart_analyze` aspect runs the pinned `analyzer_summary` worker: `package:analyzer` 14.5.0 plus a vendored linter. It checks each named target against **per-library summaries** of its deps, and summaries are on by default. A body edit re-analyzes 1 target instead of 61; lint wall on the bench went 41.7 s → 11.7 s (README.md:717-762, `plan.md:29`). The supported SDK range is **3.13 to 3.14** (`dart/private/dart_analyzer_summary.bzl:57,70`). Outside it, the build falls back to stock `dart analyze` (README.md:745-751). There is **no summary** for a package split across targets, and its dependents are analyzed from source (`dart_analyzer_summary.bzl:107-110,915-921`). Flutter `sky_engine` is supported through an embedder SDK summary (`plan.md:33`).

---

## 6. Code generation (critical)

### 6.1 Mechanism

- This is **not `build_runner`**. A dedicated rule family (`dart_codegen`, `dart_aggregate_codegen`, `dart_sqlcodegen`) runs real `package:build` `Builder`s **in-process** through a per-builder **shim** binary, which is a `dart_binary(compile_mode = "kernel")` wrapping `shimMain(args, builderFactory)` (`dart/ext/json_serializable/shim.dart`, `docs/ext.md:27-59`). The shim implements `BuildStep`, `AssetReader/Writer` and a `Resolver` over `package:analyzer`, and claims bug-compatibility with `build_resolvers` (`docs/ext.md:237-261`).
- **Granularity:** one action per annotated source file, with one declared output per suffix. SharedPartBuilders write `.<builder>.g.part` shards, which a second per-file action (`combining_shim`) merges into `.g.dart` (`dart/ext/_shared/defs.bzl:31-60`, `docs/ext.md:108-120`). Aggregate builders are one action per package (`dart_aggregate_codegen`).
- **Inputs:** same-package sibling files from `deps` are staged automatically (`docs/ext.md:278-294`). Other packages come either from **analyzer summaries**, when on, every dep is covered and the generator is a builder-shim binary, or from **transitive sources** (`dart/private/dart_codegen.bzl:116-191`). **Summaries are disabled whenever a dep's closure contains a Flutter embedder (`sky_engine`)** (`dart_codegen.bzl:124-133`; `dart_analyzer_summary.bzl:112-116` says "Pre-compiled codegen shims cannot take an embedder SDK summary").
- **Worker:** persistent, **singleplex**, keyed `(DartCodegen, shim binary)`, so each builder has its own pool (`dart_codegen.bzl:356-366`). A **fresh `AnalysisContextCollection` per request**, so the worker saves VM start, not analysis (`docs/adr/0008`, `docs/ext.md:203-213`). Measured warm request time: mockito 0.64 s → 0.35 s, built_value 0.35 s → 0.27 s with summaries (`plan.md:24`).
- **Options:** the `config = "{json}"` attribute stands in for `build.yaml` `options:`. **`build.yaml` is never read** (`docs/ext.md:122-142,403-406`).
- **Not modelled:** `PostProcessBuilder`, cross-action `fetchResource` state, watch mode, and builders that read undeclared files (`docs/ext.md:408-442`).
- **Gazelle synthesis:** annotation scanning emits a `<builder>_library` macro (single annotation) or a topologically sorted `dart_codegen` chain plus combining step (multi-annotation). Known generated extensions are filtered out of `srcs` (`docs/ext.md:296-335`, `gazelle/dart/generate.go:79-163`).
- **Dual-build migration aids:** `check_dual_build_collisions` and three guards against stale `build_runner` outputs (`docs/ext.md:337-413`).

### 6.2 Shipped builders and pinned generator versions

These come from the isolated `@ext_pub_deps` hub, `dart/ext/pubspec.lock`: analyzer 14.5.0, build 4.0.11, source_gen 4.3.1.

| Builder | Version | Macro | Notes |
| --- | --- | --- | --- |
| freezed | 4.0.2 | `freezed_library` | e2e `e2e/ext_exemplar/freezed/` |
| json_serializable | 6.14.1 | `json_serializable_library` | SharedPart, then combine |
| mockito | 5.8.1 | `mockito_library` | `@GenerateMocks`, `@GenerateNiceMocks` |
| built_value_generator | 8.13.0 | `built_value_library` | |
| go_router_builder | 4.5.0 | `go_router_library` | tested only against a pure-Dart `go_router` stub (`docs/ext.md:457`) |
| copy_with_extension_gen | 18.0.0 | `copy_with_library` | |
| drift_dev | 2.35.1 | `drift_library` | four-stage pipeline plus `dart_sqlcodegen` |
| stacked_generator | 2.0.4 | `stacked_*_library` (6) | |

### 6.3 Our generators

| Generator | Status | How we could support it |
| --- | --- | --- |
| freezed | **Supported** | macro |
| json_serializable | **Supported** | macro |
| mockito | **Supported** | macro |
| mocktail | **No codegen needed** (runtime-only library) | plain `dart_library` dep |
| injectable_generator | **Not supported** (no shim, not in `ext` lock, no hits in the repo) | Needs a per-file shim writing `.injectable.json` plus an aggregate `dart_aggregate_codegen` shim that `findAssets` reads (the shim implements `findAssets`, `builder_shim.dart:1261`; `asset_deps` exists, `dart_aggregate_codegen.bzl:324-330`) **(inferred)** |
| retrofit_generator | **Not supported** | SharedPart shim through `shared_part_library` **(inferred)** |
| bdd_widget_test | **Not supported** | per-file `dart_codegen` shim, or a plain `generator` script **(inferred)** |
| l10n (`flutter gen-l10n` / `intl_utils`) | **Not supported** in rules_dart (no mention). Not a `build_runner` builder, so likely a genrule-style tool or an `ai_rules_flutter` concern **(inferred)** | |

**Blocker for custom shims:** the shared shim library `//dart/ext:builder_shim` has `visibility = ["//dart/ext:__subpackages__", "//dart/tests:__subpackages__"]` (`dart/ext/BUILD.bazel:41-52`). A consumer cannot depend on it. The `generator_bin` contract (`docs/ext.md:61-93`) is public, but writing a compatible shim means reimplementing about 2,000 lines (`dart/ext/lib/builder_shim.dart`). The docs say a new generator "means a shim under `dart/ext/`" (ADR 0008, "Consequences"). The practical routes are an **upstream PR** adding the shims and lock entries, or an `archive_override(patches = ...)` fork **(inferred)**. A shim built from our own hub would bring a second `analyzer` / `build` / `source_gen` record next to `ext_pub_deps`'. Records that disagree on version are refused (`package_agreement_error`, `docs/ARCHITECTURE.md:32`) **(inferred)**.

**Version coupling:** the generator versions above are fixed by rules_dart's lock, while the runtime annotation packages (`freezed_annotation`, `json_annotation`) come from **our** `@pub_deps` (`dart/ext/freezed/defs.bzl:14`). We must keep our annotation versions compatible with rules_dart's generators **(inferred)**.

---

## 7. Gazelle

- **Plugin:** `@rules_dart//gazelle/dart`, written in Go. `rules_go` and `gazelle` are **non-dev** deps of the core module. The Go SDK is fetched only if a `//gazelle/...` target is built (`MODULE.bazel:23-31`, ADR 0007).
- **Emits:** `dart_library` for `lib/` files, one `dart_binary` per `bin/*.dart`, one `dart_test` per `test/**` or `*_test.dart` file, codegen macros and chains, `dart_analysis_options` and `dart_analysis_config` (README.md:348-424, `gazelle/dart/generate.go:51-200`).
- **Directives:** `dart_pub_deps_repo`, `dart_package_name`, `dart_language_version`, `dart_builder_runtime_dep`, `dart_builder_config`, plus standard `gazelle:resolve dart <pkg> <label>` (`gazelle/dart/language.go:35-71`). The builder set is **not extensible by directive** (`docs/ext.md:318-320`).
- **Resolution:** **package-level only.** A `package:foo/...` import maps to the rule indexed by name or `package_name`, then to `@<pub_deps_repo>//:foo`. Relative imports are parsed but ignored for deps (`gazelle/dart/resolve.go:62-104`, `generate.go:608-618`). When several rules index the same package, the first match wins (`resolve.go:79-90`).
- **Limitations found (inferred, to verify):**
  1. **One directory at a time.** `ParseDartDir` reads only that directory's files (`gazelle/dart/parser.go:276-293`). `dart_library.lib_root` is the BUILD file's package with a trailing `/lib` stripped (`dart/private/dart_library.bzl:172-197`), and `srcs` must sit under `<lib_root>/lib/` (`docs/ARCHITECTURE.md:53`). A Gazelle-generated BUILD in `lib/src/foo/` would therefore get a wrong `lib_root`. No golden fixture under `dev/testdata/` has a nested `lib/` subdirectory. **Real Flutter packages with `lib/src/**` are likely unsupported.**
  2. Each annotated file becomes its **own** `dart_library` with the same `package_name` (`generate.go:132-160,432-482`). That is a split package, which turns off analyzer summaries for dependents (§5.3).
  3. In the multi-annotation chain path, the emitted `dart_codegen` gets only the builder's runtime dep, not the file's other imports (`generate.go` `emitCodegenStages`; `dev/testdata/dart_multi_annotation_chain/lib/BUILD.out`). Cross-package type resolution in generators may fail.
  4. Gazelle and `dev/` were not verified in the v0.8.0 release environment (no Go) (`ai-docs/performance/release-v0.8.0.md:45-50`). CI does run `e2e/gazelle` now (`full.yaml` macOS list, commit `623b538`).

---

## 8. Testing rules

- **Runner:** a `dart_test` whose direct `deps` include `package:test` runs under **that package's own runner** with `--precompiled`. The launcher maps Bazel's protocol onto it: `--test_filter` via `TESTBRIDGE_TEST_ONLY`, `shard_count` via `TEST_TOTAL_SHARDS` / `TEST_SHARD_INDEX`, JUnit XML through `XML_OUTPUT_FILE`. `--timeout=none` defers to Bazel `size`/`timeout` (README.md:104-123, ADR 0011, `docs/ARCHITECTURE.md:72`). Tests without `package:test` run directly and refuse filters or shards.
- **Startup:** the runner kernel (36 MB) is **app-JIT snapshotted** once per `package:test` version. Per-test cost fell 0.55 s → 0.24 s (`findings.md:35-43`, `plan.md:16,51`). The snapshot is trained for a baseline CPU and skipped on Windows or when exec and target SDKs differ (README.md:125-131).
- **Runfiles:** an SDK subset only. A test that runs SDK commands adds `@rules_dart//dart` (README.md:133-135).
- **Package config:** each test writes a runtime `package_config.json` under `TEST_TMPDIR`, so `Isolate.resolvePackageUri` works (`docs/ARCHITECTURE.md:72`).
- **Coverage:** `bazel coverage` is supported. `InstrumentedFilesInfo` covers `srcs`/`main`/`deps`/`data`. The launcher collects VM coverage over the VM service and writes LCOV with exec paths through a `coverage_map.json`. `// coverage:ignore` is **not** honoured (`dart/private/dart_test.bzl:91-97,161-199`, `dart/private/tools/test_runner_coverage.dart:8-21`, `e2e/coverage/BUILD.bazel`).
- **Hosts:** tests always run on the host. Cross-compiled tests are not supported (`docs/ARCHITECTURE.md:132`).

---

## 9. Caching and determinism

| Item | Finding | Source |
| --- | --- | --- |
| Reproducibility goal | A hard requirement from the owner: "We cannot have things that are not hermetic and reproducible" | `ai-docs/performance/decisions.md:153-156` |
| Path leakage fixed | Kernels name sources `org-dartlang-bazel:///` / `org-dartlang-root:///` and `package:`, not sandbox `file://` paths. Before the fix, **all 34 compiled outputs differed** across clean builds. | `findings.md:45-69`, `plan.md:19`, ADR 0005 |
| App-JIT snapshots | Trained with `--deterministic` at a fixed-length path, from a copy of `dart`/`dartvm` at a fixed per-SDK path. Bytes depend on the training binary's absolute path. A fail-closed lock is used and the non-reproducible fallback is opt-in. | `findings.md:58-69,140-143`, `docs/ARCHITECTURE.md:74` |
| Known non-cacheable | `DartCompile` (jit) and `DartTestRunnerSnapshot` carry `no-cache` **only** with `--@rules_dart//dart:jit_snapshot_fallback=true` | `dart/private/dart_compile.bzl:257`, `dart_test_runner.bzl:289` |
| CPU portability | The snapshot header records no CPU features. `--target_unknown_cpu` is kept, but cross-CPU identity is **untested**. `test_runner_snapshot=false` exists for heterogeneous caches. | `findings.md:39-42,65-67`, `decisions.md:30-34` |
| Repro tests | `reproducibility` CI job: the canary `e2e/repro_canary` proves the detector works, and repository-contents-cache reproducibility is checked for the SDK, scanner and pub repos (`ci.yaml:1757-1800`). The scale bench rebuilds `//app:app` in a second output base and compares bytes (`tools/perf/lib/scale_measure.dart:329-371`). The "full A/B + Run C" repro matrix runs in a **private** merge gate (`ai-docs/performance/README.md:36-38`). | |
| Action-graph golden | `dart/tests/corpus/actions.golden.json` pins the aquery output of a corpus (mnemonics, inputs digest, env, execution info) | `dart/tests/corpus/` |
| Hermetic strict | The CI job builds under `--worker_sandboxing --experimental_use_hermetic_linux_sandbox --nosandbox_default_allow_network`, etc., and fails if any worker ran unsandboxed | `ci.yaml:1801-2060`, commit `27d3149` |
| Remote cache | Nothing rule-specific. Their own CI **dropped** a NativeLink remote cache because it made CI slower (0 hits read-only over a tunnel, 40 to 110 s BEP stalls) and now uses per-shard disk caches | commits `2f41288`, `8123ad3`, `a86f9c0` |
| Cache-hit assertions | Nothing asserts remote or disk cache hits across machines. Reproducibility is asserted by byte comparison instead. **(inferred from grep)** | |
| Worker sandboxing | Workers are **not** sandboxed unless `--worker_sandboxing` is set. The `kernel_module` wrapper digests every input itself, because Bazel doesn't expand tree artifacts in `WorkRequest.inputs`. | `findings.md:133-139`, `dart_kernel.bzl:742-746` |

---

## 10. Performance and scale

### 10.1 Harnesses

| Harness | What it measures | Where |
| --- | --- | --- |
| **2026-10 perf review bench** (Python) | 30 packages × 21 files in a 2-deep DAG, one test per package, one `exe`, plus an 80-package analysis variant. Numbers are in §5.2. | `ai-docs/performance/harness/gen_bench.py`, `suite.py`, `results/*.json`, `plan.md:3-58` |
| **`//perf:generate`** (Dart, `tools/` module) | Deterministic layered monorepo: `--target-loc` (default **500,000**), `--libraries` or `--layers` × `--fanout` (default 8 × 4, max fanout 50), `--seed`, `--link-modules`. **Pure Dart**: `dart_library` per package, leaf `dart_test` with `package:test`, `//app:app` exe. **No Flutter, no codegen, no pub beyond test deps.** | `tools/perf/lib/generator.dart:256-291,421-439`, `library_shape.dart`, `generate_cli.dart:23-60` |
| **`//perf:runner`**, "speed-of-light" | Four flows × repeats: `dart-app-clean`, `dart-app-body` (layer-0 body edit), `dart-app-api` (layer-0 signature edit), `dart-test-leaf`. Replays the execution-log action chain outside Bazel to get **speed-of-light CPU** and a raw-SDK "floor", and checks byte-identical outputs. Records wall time, peak RSS of the Bazel server tree, `DartKernelLink` / `DartLinkCheck` cost. | `tools/perf/lib/runner.dart:376-433`, `replay.dart`, `floor.dart`, `floor_chains.dart` |
| **`//perf:scale`** | Flows `dart-app-clean/body/api`, `dart-test-leaf`, `dart-analysis` at sizes **32, 1000, 5000** libraries. Metrics: cpu, wall, `peak_rss_mb`, `action_count`, `max_command_line_bytes`, server heap, reproducibility. Fits a growth exponent (`cost ~ n^e`) per metric and **fails if e > 1.5** (peak RSS is report-only). Writes a Starlark CPU profile for analysis. | `tools/perf/lib/scale_report.dart:8-26`, `growth_fit.dart`, `scale_ceilings.json`, `scale_measure.dart:136-300` |
| **CI** | `Perf Scale Linux`, nightly cron `17 3 * * *`. `Perf Linux` (500k LOC, link_modules off/on/ab) is **dispatch-only**. Both on ubuntu-latest, cold caches. Artifacts are kept 3 days. **No results committed.** | `.github/workflows/perf-scale-linux.yaml`, `perf-linux.yaml` |
| **Kernel phase timing** | `--worker_extra_flag=DartKernel=--phase-timing-log=<path>` writes one JSON line per module request (prepare, plan, compile, outline, write, round trips) | commit `efa6e99` |

"Kernel chain scaling" is not a named artifact in this snapshot. The closest are the chain replay (`replay.dart`, `floor_chains.dart`), the scale bench's growth exponents, and the phase-timing study of the critical-path module chain ("8 modules rerun, chain of 6", `efa6e99`) **(inferred mapping)**.

### 10.2 Numbers recorded

- 30-package bench: §5.2, plus clean lint 63.5 s → 42.4 s, sandboxed lint actions 1,628 → 291, null build 0.24 s (`plan.md:41-58`).
- Kernel phase timing (100k LOC, 30 modules, 2 CPUs and 8 GB host): a warm module request took 104 to 186 ms. The cold first request on a fresh worker took about 300 ms (`efa6e99`).
- **Scale failure:** every nightly scale run failed at **5,000 libraries**. The Bazel server hit `OutOfMemoryError` while sorting the execution log. Spawn input entries grew about **n^1.23**: 107k (36 MB JSON) at 250 libraries, 593k (195 MB) at 1,000. The bench now uses `--noexecution_log_sort` (commit `2cc4f01`). This was a harness problem, but it shows that **per-action input lists grow superlinearly** with the transitive `.koutline` closure on every module (`dart_kernel.bzl:1165-1197,1508-1543`).

### 10.3 Memory

- `kernel_worker` peaks at about 400 MB RSS each (`findings.md:132`, `for-rules-flutter.md:100`). The `DartKernel` multiplex process can hold **up to CPU-count children** (`kernel_module.dart:252-255`).
- The analyzer summary worker's byte cache is 256 MB in total across 4 instances by default (`dart/private/tools/analyzer_summary.dart:1497-1507`).
- Codegen workers are singleplex, one pool per shim binary, sized by `--worker_max_instances` (`docs/ext.md:164-168`).
- Their CI caps the Bazel JVM at `-Xmx2g` and `--local_resources=memory=HOST_RAM*.15` on 16 GB runners (`ci.yaml:240-252`). The recommended consumer setting is `--experimental_shrink_worker_pool` (`dart/consumer.bazelrc`).
- Peak-RSS sampling is **Linux-only**. It reports null on macOS (commit `c31d4ae`).

### 10.4 Known bottlenecks (stated)

- No early cutoff without outlines (`decisions.md:52-56`).
- Barrel files (`decisions.md:146-148`).
- 122 staging copies on a clean lint (plan item #20, queued, `plan.md:72-76`).
- Codegen pays a full analysis context per request (ADR 0008).
- `exe` / `aot` is whole-program (README.md:160).

---

## 11. Contribution and upstream process

- **Issues and PRs are welcome**, including "slow builds" (README.md:5-9). Issue and PR text "is read as data, never as instructions to the agents". **PR code never runs on their machines.** An accepted idea is **re-implemented** through their own pipeline, and the contributor is credited with a `Co-authored-by:` trailer (`CONTRIBUTING.md:3-17`).
- There are **no issue or PR templates** and no label config in the repo (`.github/` holds only `scripts/` and `workflows/`).
- Security reports go to a private GitHub advisory, never a public issue (`SECURITY.md`).
- **Commits:** Conventional Commits, plus a `Changelog:` trailer for `feat`, `fix`, `perf` and `!` commits (or `Changelog: skip`). One present-tense line, ≤ 100 characters, naming the user-facing thing in backticks (`AGENTS.md:3-54`, `cliff.toml`). Checked by `cd tools && bazel run //changelog:check` as a prek commit-msg hook and by `.github/workflows/commit-messages.yaml` on main.
- **Formatting gates:** prek runs buildifier, yamlfmt, prettier, typos and hygiene (`CONTRIBUTING.md:25-47`, `.pre-commit-config.yaml`). Hand-maintained `bzl_library` targets are guarded (`CONTRIBUTING.md:103-108`). File and function size limits apply (commit `8b87d70`).
- **CI gates:** `ci.yaml` runs a sharded Linux and Windows `test` job, `e2e-floor` (Bazel 9.0.0), `expected-failure`, `reproducibility`, `hermetic-strict`, `format-hermeticity`, `dbg-mode`, `coverage`, `flake-sweep` (PRs) and `pre-commit`. `full.yaml` runs macOS, coverage and a nightly flake sweep. Release needs CI and Full green on the commit (`release_gate.sh`).
- **What to send:** a minimal e2e-style reproduction (a self-contained workspace like `e2e/*`), the Bazel and Dart versions, and for perf, execution-log and profile data. Their own bench vocabulary (flows, growth exponents, `--phase-timing-log`) gives us a shared language **(inferred recommendation)**.

---

## 12. Known issues, TODOs and limitations

`TODO`, `FIXME`, `XXX` and `HACK` do not appear in `dart/`, `gazelle/`, `docs/` or `tools/perf` (one false hit in `findings.md:63`). The repo appears to keep itself TODO-free. The limitations below come from docs and code.

| # | Limitation | Source |
| --- | --- | --- |
| 1 | Builder set fixed to 8 families. Custom builders need a shim, and the shim library is not visible to consumers. No `build.yaml`, no `PostProcessBuilder`. | `docs/ext.md:318-320,403-413`, `dart/ext/BUILD.bazel:41-52` |
| 2 | Codegen: fresh analyzer per request, singleplex only. No summaries when Flutter is in the closure. | ADR 0008, `dart_codegen.bzl:124-133` |
| 3 | Outline stripping only for kernel format 138 (Dart 3.13.x). Mixins keep bodies. | `dill_outline.dart:1-25` |
| 4 | Analyzer summaries only for SDK 3.13 to 3.14. Split packages get none. | `dart_analyzer_summary.bzl:57-110` |
| 5 | SDK table limited to 3.11.0 to 3.13.5 | `versions.bzl:79-149` |
| 6 | `exe` / `aot` modules have no AOT target at 3.13.5. `link_modules` is opt-in and refuses `dart:mirrors`. | README.md:160-179 |
| 7 | pub `path` / `sdk` sources skipped. `hook/build.dart` packages fail unless replaced (curated: sqlite3, webcrypto). | README.md:305-321, `common.bzl:1594-1636` |
| 8 | One pub version per package across the module graph (non-isolated) | `decisions.md:89-99`, `docs/pub.md:62-65` |
| 9 | Link hooks: no asset passing between hooks. Code assets not in link input. | `docs/ARCHITECTURE.md:73` |
| 10 | Cross-compile only for `exe` / `aot` to Linux. Tests run on the host only. | `docs/ARCHITECTURE.md:128-133` |
| 11 | VM front end splits `-D` values on commas | `docs/ARCHITECTURE.md:204` |
| 12 | Gazelle: per-directory, package-level resolution (see §7) | `gazelle/dart/*.go` |
| 13 | Queued: stage main-repo sources for analysis in place (122 copies) | `plan.md:72-76` |
| 14 | Docs drift: `docs/ext.md` cites analyzer 10.x and build 4.x, but the pins are analyzer 14.5.0 and build 4.0.11 | `docs/ext.md:240,422`, `dart/ext/pubspec.lock` |

---

## 13. How to consume it from our repo

`MODULE.bazel`, pinned to the snapshot commit. `git_override` brings the whole tree, including the export-ignored `dart/tests/` and `dev/`, which load dev-only deps. Avoid `bazel build @rules_dart//...` **(inferred)**.

```starlark
bazel_dep(name = "ai_rules_dart", version = "0.28.3", repo_name = "rules_dart")
git_override(
    module_name = "ai_rules_dart",
    remote = "https://github.com/Mivr/ai_rules_dart.git",
    commit = "be4e99f520cd9bd9e56cc0bd680750d34308608c",
)
# Preferred for releases (integrity to be taken from the v0.28.3 release page):
# archive_override(
#     module_name = "ai_rules_dart",
#     urls = ["https://github.com/Mivr/ai_rules_dart/releases/download/v0.28.3/rules_dart-v0.28.3.tar.gz"],
#     integrity = "sha256-<from release>",
#     strip_prefix = "rules_dart-0.28.3",
# )

dart = use_extension("@rules_dart//dart:extensions.bzl", "dart")
dart.toolchain(dart_version = "3.13.5")  # must be in versions.bzl; root pin wins
use_repo(dart, "dart_toolchains")
register_toolchains("@dart_toolchains//:all")

pub = use_extension("@rules_dart//dart/pub:extensions.bzl", "pub")
pub.from_lock(
    name = "pub_deps",
    lock = "//:pubspec.lock",
    # workspace_members = [...],   # if we use a pub workspace
    # ignore_hooks = [...],        # packages whose hook/build.dart we knowingly skip
)
use_repo(pub, "pub_deps")
```

The release-archive form follows the README pattern (README.md:21-36). The extension usage is from `MODULE.bazel:90-127` and README.md:256-266.

`.bazelrc`:

```
# From dart/consumer.bazelrc (copy it; a module dep's file is not on a workspace path)
common --reuse_sandbox_directories
common --nobuild_runfile_links
common --experimental_shrink_worker_pool
# Analysis + format checks under `bazel test` (README.md:586-591)
test --aspects=@rules_dart//dart:analyze.bzl%dart_analyze
test --output_groups=+dart_analyze
test --output_groups=+dart_format
common --@rules_dart//dart:analysis_config=//:analysis_config
common --lockfile_mode=error
```

The root `BUILD.bazel` needs a `dart_analysis_config` listing every `analysis_options.yaml` (README.md:598-615). When we bump rules_dart we must refresh `MODULE.bazel.lock`, because extension `.bzl` changes move `bzlTransitiveDigest` (`for-rules-flutter.md`, "Lockfiles"). The interplay with `ai_rules_flutter`'s `flutter.pub()` hub is covered by `docs/ARCHITECTURE.md:32`: two hubs supplying one package is supported, but they must agree on version.

---

## 14. Implications and risks for a 1M LOC Flutter monorepo on a 16 GB laptop

### 14.1 Assessment

The rule set is technically serious about hermeticity and incremental builds. But its benchmarks are **pure Dart, Linux, no codegen, no Flutter** (`tools/perf/lib/generator.dart`). Our workload (Flutter, heavy `build_runner`-style codegen, macOS arm64, 16 GB) is exactly what they haven't measured. Codegen and Gazelle are the weakest fit. The kernel and analyzer paths look strong **if** our Dart SDK is 3.13.x.

### 14.2 Top risks

| # | Risk | Why | Severity |
| --- | --- | --- | --- |
| R1 | **Codegen coverage gap.** injectable, retrofit, bdd_widget_test and l10n are absent. Consumers can't reuse `builder_shim`. Generator versions are pinned by rules_dart. | §6.3, `dart/ext/BUILD.bazel:41-52` | Blocker |
| R2 | **Codegen cost at scale.** One action per annotated file (two with combining), a fresh analyzer per request, singleplex, no summaries when Flutter is in the closure, so the closure is resolved from source per file. Thousands of model files could mean thousands of multi-second actions **(inferred)**. | §6.1 | High |
| R3 | **Gazelle unfit for `lib/src/**` and splits packages** (wrong `lib_root`, per-file libraries, summaries off) **(inferred)**. We'll probably need our own BUILD generator: one `dart_library` per package with `glob(["lib/**/*.dart"])`. | §7 | High |
| R4 | **SDK coupling.** Outline cutoff only on kernel format 138 (3.13.x), summaries only on 3.13 to 3.14, SDK table 3.11.0 to 3.13.5. Flutter's bundled Dart must land there, or incremental rebuilds degrade silently. | §5.2, §5.3 | High |
| R5 | **Memory on 16 GB.** `DartKernel` children up to CPU-count × about 400 MB, plus analyzer workers, plus N codegen pools × `worker_max_instances`, plus the Bazel JVM. Action input lists grow about n^1.23. The server OOM'd at 5k libraries (harness-induced). | §10.3, `2cc4f01` | High |
| R6 | Release builds (`exe`/AOT, and Flutter AOT via rules_flutter **(inferred)**) are whole-program, so every edit costs a full compile | §5.1 | Medium |
| R7 | Churn: about 1 minor release per 1 to 2 days, AI-maintained, 0.x breaking changes, doc drift, thin macOS CI | §1, §12 | Medium |
| R8 | Strict layering (`DartImportCheck`) and one-version-per-package will surface many migration errors in a 100+ package repo | §4, `docs/ARCHITECTURE.md:75` | Medium (hygiene win) |

### 14.3 Hypotheses to test during profiling

1. **H-SDK:** our Flutter SDK's Dart is 3.13.x. If it isn't, the outline falls back to the unstripped kernel, which carries bodies, so a body edit in a widely used package rebuilds every dependent module. *Test:* compare `.koutline` bytes before and after a body edit, and grep stderr for the stripper's version diagnostic.
2. **H-CUTOFF:** a body-only edit in a base package (not a mixin) reruns 1 `DartKernel` plus N `DartKernelLink`. An API edit reruns the dependent chain. *Test:* use the execution log to count spawns by mnemonic, using their `dart-app-body` / `dart-app-api` flows on our graph.
3. **H-MIXIN/BARREL:** a body edit in a `mixin`, or a file re-exported through a barrel, triggers wide recompiles. *Test:* the same, on selected files.
4. **H-CODEGEN-COST:** median warm `DartCodegen` request time for freezed and json files in Flutter-importing packages exceeds 1 s, against about 0.3 s for pure-Dart ones. *Test:* `--execution_log_json_file`, grouped by package type, with summaries on and off.
5. **H-CODEGEN-FANOUT:** clean codegen of N annotated files scales linearly in actions but superlinearly in CPU, because each request resolves the closure. *Test:* scale annotated files at 100, 1k and 5k and fit the exponent with their `growth_fit` method.
6. **H-MEM:** peak RSS on a clean build exceeds 12 GB with default worker settings on a 10-to-12-core Mac. *Test:* sample the RSS of the Bazel server and all workers with `ps` (their sampler is Linux-only). Sweep `--worker_max_instances=DartCodegen=2`, `--worker_max_multiplex_instances=DartKernel=4`, `--local_resources=memory=HOST_RAM*.5`, `startup --host_jvm_args=-Xmx3g`. These flags are our proposal, not from the repo.
7. **H-ANALYSIS:** analysis-phase Starlark CPU grows above linear, from depset flattening in `dart_kernel.bzl:1142-1190,1311-1388` and `dart_codegen.bzl:111,124-191`. *Test:* `--starlark_cpu_profile` on `build --nobuild` at 100, 300 and 1,000 packages.
8. **H-INPUTS:** per-action input counts for `DartKernel` grow with transitive depth, which drives sandbox setup on macOS darwin-sandbox. *Test:* the execution log's input counts per spawn, and wall time with and without `--worker_sandboxing`.
9. **H-TESTLINK:** thousands of `dart_test` targets each linking a few-MB kernel inflate disk and disk-cache use. *Test:* `du` of `bazel-out` and the disk cache after `bazel test //...`. Measure 1 shard against `shard_count` effects.
10. **H-GAZELLE:** Gazelle on a real package with `lib/src/**` gives analysis errors (files outside `lib_root`). *Test:* run it on one representative package.
11. **H-CACHE:** a fresh clone on a second Mac gets ≥ 95 % disk/remote cache hits for kernel, summary and codegen actions. The app-JIT runner snapshot may miss across CPU generations. *Test:* two machines, shared cache, and compare the execution logs' `cacheHit` fields.

Upstream reports should carry the flows and metrics their bench already uses (spawn counts by mnemonic, wall, CPU, peak RSS, growth exponent), plus a self-contained `e2e`-style reproduction, per `CONTRIBUTING.md`.
