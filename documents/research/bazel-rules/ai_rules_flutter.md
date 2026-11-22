# Research: `ai_rules_flutter` (Bazel rules for Flutter) — iOS and macOS host focus

- **Task:** T-0013 (research wave). Researcher, mini-client fleet.
- **Source:** shallow clone of `https://github.com/Mivr/ai_rules_flutter` at HEAD `876e263` (2026-11-16), which is tag `v0.30.2`. Every path below is relative to that checkout. Nothing in it was run; this is a reading-and-grep study.
- **Scope:** iOS device and simulator builds, plus macOS arm64 host builds and tests. Android, web, Linux and Windows are mentioned only where they show a mechanism.
- **Convention:** **(inferred)** marks a conclusion drawn from reading, not something the repo states or measures.

---

## 1. Summary and maturity

| Item | Finding | Source |
|---|---|---|
| Purpose | Bazel rules that compile Dart to kernel (JIT) or AOT, bundle assets, and package apps for macOS, iOS, Android, Linux, Windows and web. They ship a dev tool, `flutter_bazel`, for hot reload. Platform packaging is handed to `rules_apple`, `rules_android` and similar rule sets. | `README.md:14-20` |
| Status | **Alpha**: "the public API may still change". | `README.md:18` |
| Who builds it | "Written, reviewed, tested and released by AI agents". The human owner is @Mivr. It continues `aran/rules_flutter` (Aran Donohue wrote 323 commits). | `README.md:1-12`, `README.md:2782-2795`, `CONTRIBUTING.md:5` |
| Module | `module(name = "ai_rules_flutter", repo_name = "rules_flutter", bazel_compatibility = [">=9.0.0"])`. It has no `version` field; the publish workflow patches one in. | `MODULE.bazel:1-27` |
| Bazel | `.bazelversion` is `9.3.0`. BCR presubmit tests Bazel `9.0.0`, `9.x` and `rolling`. Bazel 10.0.0rc1 failed in C toolchain autoconfig and is parked. | `.bazelversion`, `.bcr/presubmit.yml`, `ai-docs/performance/findings.md:123-135` |
| bzlmod | bzlmod only. The `flutter` module extension has the tags `toolchain`, `version`, `pub`, `plugin_overlays` and `darwin_sdk`. | `flutter/extensions.bzl:847-855` |
| Release cadence | Tags `v0.30.0`, `v0.30.1` and `v0.30.2` were all cut on 2026-11-16. `auto-release.yaml` releases every `main` commit that passes CI and Full and carries a `Changelog:` trailer. A `feat` commit bumps the minor version, anything else bumps the patch. | `git tag`, `.github/workflows/auto-release.yaml:1-15` |
| BCR | Not yet on the BCR (`.bcr/metadata.template.json` has `"versions": []`). Consumers take GitHub release archives through `archive_override`. | `.bcr/metadata.template.json`, `README.md:58-89` |
| Default Flutter | 3.47.7. Stock pins run 3.41.2 to 3.47.7 (10 releases). | `MODULE.bazel` (`flutter.toolchain(flutter_version = "3.47.7")`), `flutter/private/versions.bzl:48-104` |
| Hosts with checksummed tools | darwin-arm64, darwin-x64, linux-x64, linux-arm64, windows-x64. macOS-only release and profile `gen_snapshot` tool sets exist. | `flutter/private/versions.bzl:281-357` |
| Targets | macOS, iOS (device arm64; simulator `sim_arm64` in debug only), Android, Linux, Windows, web. | `README.md:569-1604` |
| Apple stack floors | `rules_apple` ≥ 4.5.3 and `rules_swift` ≥ 3.5.0. The repo itself builds with rules_apple 5.2.0, rules_swift 4.1.2 and apple_support 2.9.1. | `MODULE.bazel:57-75`, `MODULE.bazel:204-216` |

**Relationship to `ai_rules_dart`.** It is a hard dependency with a floor of **`ai_rules_dart` 0.28.3** (`MODULE.bazel:129`, `flutter/private/rules_dart_floor.bzl:19`). The extension fails early when it resolves an older version. The repo's own builds `git_override` ai_rules_dart to `e7163aab8f9171f54693cd1b99feb7d3cee9602d` (`MODULE.bazel:177-181`). What Flutter takes from rules_dart:

- the `DartInfo` contract: every `deps` attribute is typed `providers = [DartInfo]` (`docs/ARCHITECTURE.md:159-168`);
- `dart_codegen` and `dart_aggregate_codegen` (`README.md:2188-2222`);
- the `dart_analyze` aspect and analyzer summaries;
- modular kernel actions (`DartKernel` and `DartKernelLink`, `ai-docs/performance/findings.md:439-446`);
- the layering check (`docs/ARCHITECTURE.md:78-108`).

Flutter's bundled Dart SDK is registered as *the* rules_dart toolchain, so a workspace has one Dart (`README.md:2305`, `ai-docs/performance/plan.md` item T1).

**Maturity verdict (inferred).** The surface area is very broad: 15 public `.bzl` facades and 159 private `.bzl` files (`docs/ARCHITECTURE.md:13-29`). The design is heavily fail-closed and well documented. But the project is alpha, very young as a standalone repo (it moved here on 2026-10-28, `README.md:2790-2795`), changes daily, and is verified mostly by its own e2e workspaces, all of which pin Flutter 3.47.7. Expect breaking changes between minor versions.

---

## 2. Public API

Load points are the facades under `flutter/` (`docs/ARCHITECTURE.md:11-21`).

### 2.1 Core (`@rules_flutter//flutter:defs.bzl`)

| Symbol | Kind | Key attributes | Providers |
|---|---|---|---|
| `flutter_library` | rule | `srcs`, `deps`, `assets`, `fonts`, `pkg_shaders`, `shader_includes`, `shaders`, `package_name`, `language_version` | `DartInfo`, `FlutterInfo`, `DartAnalyzableInfo`. It does not compile (`README.md:1681-1705`, `flutter/private/flutter_library.bzl:720`). |
| `flutter_application` | macro → rule | `main`, `package_name` (required, must equal the pubspec `name`), `srcs`, `deps`, `assets`, `fonts`, `flavor`, `default_flavor`, `defines`, `defines_files`, `define_flagfiles`, `native_deps`, `obfuscate`, `split_debug_info`, `extra_gen_snapshot_options`, `track_widget_creation`, `shaders`, `tree_shake_icons` (default True), `link_hook_assets`, `license_files`, `min_os_version` | `FlutterApplicationInfo` (`aot_output`, `kernel_dill`, `flutter_assets`, `icu_data`, `native_libs`, `is_debug`, …) (`README.md:1707-1751`, `README.md:2315-2325`) |
| `flutter_test` | test rule | the compile attributes plus `data`, `env`, `enable_impeller`, `include_tags`, `exclude_tags`, `shard_count` | output groups `test_kernel`, `test_base_kernel`, `test_assets`, `test_library_tags` (`README.md:1803-1893`) |
| `flutter_prebuilt_test` | test rule | `dill`, `assets`, `base_dill`, `library_tags`. Runs an already-built kernel. | (`README.md:1867-1893`) |
| `flutter_integration_test` | macro | `platform` (`web`/`linux`/`android`/`ios`), `main`, `srcs`, `app_srcs`, `deps`, `assets`, `flavor`, `ios_bundle_id`, `ios_runner_srcs`, `ios_info_plist`, tags | (`README.md:1895-1967`) |
| `flutter_gen_l10n` | rule | `arbs`, `template_arb_file`, `output_localization_file`, `output_class`, `preferred_supported_locales`, `header`, `use_deferred_loading`, `nullable_getter`, `required_resource_attributes`, `use_escaping`, `relax_syntax`, `use_named_parameters`, `suppress_warnings` | generated `.dart` files (`flutter/private/flutter_gen_l10n.bzl:202-258`) |
| `flutter_font_family` | rule | `family`, `fonts = [{asset, weight?, style?}]` | (`README.md:276-304`) |
| `flutter_plugin` | rule | `srcs`, `deps`, `platforms`, `dart_plugin_class`, `plugin_class`, `apple_libs`, `native_deps`, `native_assets`, `assets`, `pkg_shaders`, `link_hook` | `FlutterInfo` (`README.md:2037-2072`) |
| `flutter_native_library` | rule | `library`, `binding_contract`, `hot_patch` | (`README.md:492-552`) |
| `flutter_kernel_target`, `flutter_aot_target`, `flutter_asset_bundle` | low-level rules | | (`README.md:2107-2117`) |

### 2.2 iOS (`@rules_flutter//flutter:ios.bzl`)

| Symbol | Purpose |
|---|---|
| `flutter_ios_app` | Tier-1 macro around `rules_apple` `ios_application`. Attributes: `application`, `bundle_id`, `families` (default `["iphone"]`), `app_name`, `minimum_os_version` (default and floor `"15.0"`), `info_plist`, `version`, `launch_storyboard`, `entitlements`, `additional_entitlements`, `provisioning_profile`, `signing`, `app_icons`, `runner_deps`, `exclude_plugins`, `generated_registrant`, `swift_copts`, `additional_deps`, `extensions`, `backend` (`rules_apple` or `xtool`). Tagged `manual` by default. (`README.md:659-694`, `README.md:843`, `flutter/private/constants.bzl:19`) |
| `flutter_ios_framework_gen`, `flutter_ios_framework` (`split_debug_assets`), `flutter_ios_registrant_gen` (`language = "swift"` or `"objc"`), `flutter_ios_engine`, `flutter_ios_info_plist_gen`, `flutter_ios_native_frameworks_gen`, `flutter_ios_privacy_manifests_gen`, `flutter_ios_runner_lib_gen` | Tier-2 composable rules (`flutter/ios.bzl:1-55`, `flutter/ios.bzl:208-460`) |
| `flutter_ios_xcframeworks` | Add-to-app xcframework set: App, Flutter, FlutterPluginRegistrant, one per plugin (`flutter/ios.bzl:125-191`, `docs/ios-add-to-app.md`) |
| `ios_sim_debug_app`, `flutter_ios_simulator_build`, `flutter_ios_simulator_build_test` | Force `-c dbg --ios_multi_cpus=sim_arm64` on one app (`flutter/private/ios_sim_debug.bzl:24-47`, `flutter/ios.bzl:463-507`) |
| `flutter_drive_test` | Host driver against an app on the simulator (`README.md:1969-2035`) |
| `flutter_apple_plugin_library`, `flutter_apple_plugins_aggregator`, `flutter_apple_xcframework_import`, `flutter_entitlements_merge`, `flutter_darwin_xcframework_import`, `flutter_xtool_*` | Plugin, prebuilt-framework and backend helpers (`flutter/ios.bzl:68-106`, `README.md:2119-2159`) |
| `IOS_MINIMUM_OS_VERSION`, `IOS_DEFAULT_LAUNCH_STORYBOARD`, `IOS_DEFAULT_MAIN_STORYBOARD` | Constants |

### 2.3 Other facades

- **`macos.bzl`**: `flutter_macos_app` and its Tier-2 rules (`flutter/macos.bzl`).
- **`utils.bzl`**: a stable API for custom compile rules. It includes `flutter_kernel_compile_action`, `flutter_kernel_options(vm_flags, …)`, a `resource_set` parameter, `flutter_kernel_module_aspect`, `flutter_modular_test_kernel`, `flutter_modular_app_kernel` and `flutter_test_bootstrap` (`README.md:2161-2186`).
- **`providers.bzl`**: `FlutterSdkInfo`, `FlutterInfo`, `FlutterApplicationInfo`, `FlutterApplePluginInfo`, `FlutterDarwinFrameworkInfo`, `FlutterNativeAssetInfo`, `resolve_flutter_sdk_info`, `FLUTTER_OPTIONAL_TOOLCHAINS`.
- **`native_assets.bzl`**: `flutter_native_asset`, `flutter_data_asset`.
- **`native_hot_patch.bzl`**: an aspect.
- **`dev_files.bzl`**: the `flutter_dev_files` aspect the dev tool requests (`flutter/dev_files.bzl:1-64`).
- **`toolchain.bzl`** and **`repositories.bzl`**: toolchain rules and repository rules.

### 2.4 Module extension and command-line targets

- **Extension tags:** `flutter.toolchain(flutter_version | local_path, name)`, `flutter.version(...)` (root only), `flutter.pub(...)` (section 4), `flutter.plugin_overlays(roots)` and `flutter.darwin_sdk(...)` (xtool only) (`flutter/extensions.bzl:86-215`).
- **Build settings:**
  - `--@rules_flutter//flutter:profile`
  - `//flutter:incremental_kernel` (default True)
  - `//flutter:dev_incremental_serialization`
  - `//flutter:extra_dart_defines` (repeatable)
  - `//flutter/settings:apple_backend`
  - the private `//flutter/private:debug_modular_app` (default True)

  Sources: `flutter/BUILD.bazel:64-200`, `flutter/settings/BUILD.bazel`, `docs/incremental-kernel.md:39-50`.
- **Runnable targets:** `@rules_flutter//flutter:pub` (`dart pub` with the pinned SDK), `@rules_flutter//dart` (SDK pass-through), `@rules_flutter//flutter:material_icons` and `@rules_flutter//tools/dev_tool:flutter_bazel` (`README.md:439-459`, `dart/BUILD.bazel`).

---

## 3. Flutter SDK toolchain

| Aspect | How it works | Source |
|---|---|---|
| Pinning | `FLUTTER_VERSIONS` maps a tag to its engine revision, fonts URL and source-tarball sha256. `ARTIFACT_CHECKSUMS` maps each of about 58 artifacts to a sha256. A missing checksum fails the fetch. | `flutter/private/versions.bzl:1-104`, `docs/flutter-sdk-versions.md:5-14` |
| Every download pinned | All fetches go through `pinned_download` or `pinned_download_and_extract`. There is no raw `ctx.download`. | `docs/ARCHITECTURE.md:387-396` |
| Version selection | The root module's pin wins. Otherwise the highest requested version wins. Semver-ish suffixes are allowed. | `docs/flutter-sdk-versions.md:16-40` |
| Custom version | `flutter.version(version, engine_revision, source_sha256, material_fonts_url, artifact_sha256 = {...58 entries})`. Root only, and it must not duplicate a stock version. | `docs/flutter-sdk-versions.md:42-89` |
| Offline / local SDK | `flutter.toolchain(local_path = ...)` symlinks a pre-extracted SDK (`bin/cache` layout, after `flutter precache`). Root only. `~` is not expanded. The SDK is never written. | `docs/flutter-sdk-versions.md:91-147` |
| Mirrors | Use `--downloader_config`; the checksums still verify every byte. | `docs/flutter-sdk-versions.md:181-188` |
| Lazy repositories | The iOS engine hub aliases two mode repositories. A `-c dbg` build fetches only the debug (simulator) engine, and fastbuild or opt fetches only the release engine, which also carries `gen_snapshot_arm64`. | `flutter/private/flutter_ios_engine_repo.bzl:1-14`, `:49-52` |
| Engine pieces used | `dartaotruntime`, `frontend_server_aot.dart.snapshot`, `platform_strong(.dill/_product.dill)`, `gen_snapshot` (an optional sub-toolchain), `impellerc`, `flutter_tester`, ICU data, `const_finder` and `font-subset`. | `README.md:2268-2303` |
| Hermeticity extras | No `.bzl` file reads `PATH` or `FLUTTER_ROOT`. The dartdev AOT snapshot is patched at fetch time so `dart compile` cannot walk up to the execroot `pubspec.yaml`. Runnable targets get a private `HOME`. | `docs/ARCHITECTURE.md:383-385`, `docs/flutter-sdk-versions.md:149-179`, `docs/run-home.md` |

**Can we use Flutter 3.41.0 (our FVM version)? Not out of the box.** The stock table starts at **3.41.2** (`flutter/private/versions.bzl:51`), and there are three routes:

1. **Move to 3.41.2, .6 or .7.** These are stock pins, but every e2e workspace pins 3.47.7. **(Inferred)** The 3.41 lines are listed but not CI-exercised.
2. **Register 3.41.0 with `flutter.version`.** This needs about 58 checksums, which `bazel run //tools/update_flutter_version -- 3.41.0` can compute (`docs/flutter-sdk-versions.md:190-199`).
3. **Point `local_path` at the FVM install** (an absolute path, after `flutter precache --ios --macos`). This is non-hermetic, root only, and makes each laptop's SDK path part of the repo setup **(inferred)**.

**A bigger 3.41 risk.** The rules' own Dart tools are compiled with the workspace's Dart toolchain, which is Flutter's bundled Dart. Their pubspecs say `sdk: ^3.13.0` (`flutter/private/tools/pubspec.yaml:6-7`), and `docs/TESTING.md:150-206` warns that a too-old Dart "fails at *compilation*". The vendored `gen-l10n` is patched per Flutter release (`README.md:2264`). Asset rules mirror flutter_tools 3.47.7 line by line (`README.md:272`, `docs/pub-assets.md:92-100`). **(Inferred)** Flutter 3.41.x ships an older Dart than 3.13, so some rules tools may not compile on it. A possible workaround: register a newer standalone rules_dart toolchain ahead of `@flutter_toolchains` (`README.md:2305`), while the kernel compile keeps the engine's own `frontend_server` (`ai-docs/performance/decisions.md` "The kernel compile keeps the engine's dartaotruntime"). Treat this as test item H-SDK in section 16.

---

## 4. Pub packages and Flutter plugins (native iOS)

### 4.1 Pub

`flutter.pub(name, lock)` turns `pubspec.lock` into a hub (`@deps//:<pkg>`) with one spoke repository per package (`README.md:209-231`). The lock sources are handled as follows (`flutter/extensions.bzl:442-485`):

| Lock source | Handling |
|---|---|
| `hosted` | Fetched by the lock's `sha256`. An entry without one is refused (`flutter/extensions.bzl:512-516`). Custom hosted URLs are honoured. |
| `path` | Must be `relative: true` and inside the workspace. The spoke is a per-file symlink tree with generated BUILD files, and the lock must be owned by the root module (`README.md:246-250`). |
| `sdk` | `flutter`, `flutter_test`, `flutter_driver`, `flutter_localizations`, `flutter_web_plugins` and `integration_test` come from the pinned framework source (`flutter/extensions.bzl:64`). |
| **`git` (and anything else)** | **Skipped with only a `print` warning**: "Only hosted, path, and Flutter SDK packages are supported." (`flutter/extensions.bzl:480-485`) |

Further pub behaviour:

- **Cycles** (for example `dio` ↔ `dio_web_adapter`) are merged automatically into strongly-connected-component spokes. `cycle_breaks` is an optional override (`README.md:252-266`, `docs/ARCHITECTURE.md:422-429`).
- **Federated plugins** resolve per platform the way Flutter's `resolvePlatformImplementation` does (`README.md:233-244`).
- **Build hooks** (`hook/build.dart`) are never run. Curated replacements live in rules_dart's `dart/ext/registry.bzl` (for example sqlite3), overlays go in `flutter.plugin_overlays`, and `ignore_hooks` turns a hook off. An unreplaced hook that the app reaches is an error (`README.md:461-469`).
- **Lock regeneration** uses the pinned SDK: `bazel run @rules_flutter//flutter:pub -- get`. Bazel never writes the lock (`README.md:439-459`).

### 4.2 iOS plugin native code: two hub modes

| Mode | How native dependencies are found | Source |
|---|---|---|
| **SwiftPM mode** (default) | The app's `Package.resolved` (v2 or v3) becomes one spoke per pin. Every pin needs `swift_package_sha256`. A translator turns `Package.swift` into `swift_library`, `cc_library` or `objc_library`. The translator handles a strict subset of the manifest language. Escape hatches: `swift_package_build_files` (hand BUILD) and `swift_package_product_deps` (map a product to your own target). | `README.md:343-398` |
| **CocoaPods mode** (`ios_podfile_lock = "//ios:Podfile.lock"`) | It reads your committed `Podfile.lock` without running Ruby or `pod`. Each plugin's pods follow a "7-step" order: engine pods are skipped, `ios_pod_deps` mappings come next, then Flutter plugin pods, then `ios_pod_ignore`, then two stubs (binary pods and the pod-to-SwiftPM table), then refusal. | `flutter/private/flutter_pub_tag.bzl:194-240`, `flutter/private/flutter_pub_apple_pods.bzl:142-200` |

Plugin podspecs are also read statically for `frameworks`, `libraries`, `xcconfig` defines and privacy manifests (`flutter/private/podspec_read.bzl`, `README.md:419`). Each plugin's Apple sources become a `flutter_apple_plugin_library` (a `swift_library` or `objc_library`, mixed Swift and Objective-C supported; `README.md:2068-2070`). Per-plugin `GCC_PREPROCESSOR_DEFINITIONS` go through `ios_plugin_defines`, and a program-computed dependency list goes through `ios_plugin_deps` (`README.md:400-437`).

**Hard limits for a real app:**

- **Third-party pods are never auto-built.** Binary pods are stub "POD-21" and the pod-to-SwiftPM table is stub "POD-18"; both return `None` (`flutter/private/flutter_pub_apple_pods.bzl:68-92`).
  - The 14-plugin real-world matrix confirms it. In CocoaPods mode `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `google_maps_flutter_ios`, `google_sign_in_ios`, `google_mlkit_commons` and `stripe_ios` all fail with "depends on pod … which no Bazel target provides. Map it with `flutter.pub(ios_pod_deps = …)`". Only engine-only plugins (`image_picker_ios`, `url_launcher_ios`, `webview_flutter_wkwebview`, `permission_handler_apple`) resolve (`e2e/ios_plugin_matrix/expected_pods.json`, `e2e/ios_plugin_matrix/README.md:44-66`).
  - You must write Bazel targets for Firebase and similar SDKs yourself, for example with `flutter_apple_xcframework_import` over vendored xcframeworks (`README.md:2119-2159`).
- **Podspec fields are refused** when the plugin uses `vendored_frameworks` or `vendored_libraries`, `resources` or `resource_bundles` beyond privacy manifests, or `binaryTarget` in SwiftPM. Each refusal needs an overlay (`flutter/private/podspec_read.bzl:186-221`, `README.md:383-385`, `e2e/ios_plugin_matrix/expected.json` for `flutter_inappwebview_ios`).
- **Bundled overlays** cover only `audio_session`, `jni` and `objective_c` (`ext/`).

---

## 5. Build pipeline for iOS

Modes are driven by `-c` (`README.md:188-205`, `flutter/private/flutter_application.bzl:1-14`):

| `-c` | Dart output | iOS target | Notes |
|---|---|---|---|
| `dbg` | Kernel `.dill` (JIT) | **Simulator** (`--ios_multi_cpus=sim_arm64`) and device | Hot reload works. Assets plus `kernel_blob.bin` plus VM and isolate snapshots go into `App.framework/flutter_assets`. `App.framework/App` is a stub dylib embedded `bundle_only` (`flutter/private/flutter_ios_application.bzl:1-13`, `:171-260`). |
| fastbuild (default) | **AOT** (release) | Device only | **A plain `bazel build` is a release build.** |
| `opt` | AOT, stripped | Device only | |
| `opt` + `//flutter:profile` | AOT, with the VM service | Device only | There is no profile mode on the simulator (`README.md:201`). |

### 5.1 Steps (rules_apple backend)

1. **Kernel.** A debug `flutter_application` with no defines, flavor, native assets or widget-tracking *flags* compiles per-package modules. Each module is a `DartKernel` action run by persistent `kernel_worker` processes, and a link step joins them. Every other build (AOT, profile, any define or flavor) is one whole-program `FlutterKernelCompile`, run through `frontend_server` under the `kernel_filter` read guard. Debug whole-program compiles go through the warm `incr_fkc_worker` (`docs/adr/0003-kernel-compilation-per-path.md`, `docs/incremental-kernel.md:39-50`, `flutter/private/flutter_compile.bzl:199-246`).
2. **AOT.** `gen_snapshot --deterministic --snapshot_kind=app-aot-macho-dylib` writes a **Mach-O dylib directly**, with no assembly and no clang step (unlike `flutter build ios`) (`flutter/private/flutter_aot_compile.bzl:1-27`, `:440-473`). The mnemonic is `FlutterAotMacho`. `FlutterIOSRetagDylib` then rewrites `LC_BUILD_VERSION` and strips with a Dart `macho_edit` tool (`flutter/private/flutter_ios_application.bzl:100-150`).
3. **Assets.** `FlutterAssetBundle` builds `AssetManifest.bin`, `FontManifest.json`, `NOTICES.Z` and the files, then `FlutterIOSCopyAssets` (release) or `FlutterIOSDebugAssets` (debug) copies them in (`flutter/private/flutter_asset_bundle_action.bzl:453`, `flutter/private/flutter_ios_application.bzl:152-260`).
4. **App.framework import.** `apple_dynamic_framework_import`, with `bundle_only` in debug (`flutter/ios.bzl:277-317`). `flutter_ios_app` uses `split_debug_assets` on rules_apple, so a Dart edit does not make rules_apple's imported-framework processor re-copy the kernel (`README.md:734-772`, `flutter/private/ios_app.bzl:189`).
5. **Engine and runner.** Flutter.xcframework comes from the pinned engine (debug simulator or release device). A runner `swift_library` holds AppDelegate, SceneDelegate and the generated `GeneratedPluginRegistrant.swift`, plus an aggregator that links plugin libraries (`flutter/ios.bzl:391-460`).
6. **Bundle.** rules_apple's **`ios_application`** does the transition, linking, `actool`, storyboards and signing (`README.md:694`). Everything is read from `flutter create`'s `ios/Runner/` (Swift sources, `Info.plist`, `Assets.xcassets`, entitlements). The Xcode project and Podfile are **not used**.

### 5.2 Guards and targets

- **Simulator vs device.** A simulator build in fastbuild or opt is refused at analysis ("The iOS simulator runs debug builds only"), because the simulator engine cannot load AOT (`README.md:925-941`, `flutter/private/flutter_ios_application.bzl:100-107`). Use `flutter_ios_simulator_build_test` so `bazel test //...` can build simulator apps.
- **Signing.**
  - Simulator `-c dbg` bundles skip code signing by default (`apple.skip_codesign_simulator_bundles`), which saves about 3 s per edit (`README.md:821`, `ai-docs/performance/decisions.md` 2026-11-15).
  - A device build needs a `provisioning_profile` (a `local_provisioning_profile` in a git-ignored `//device` package). An unsigned device bundle needs `backend = "xtool"` (`README.md:819-923`).
  - Each extension needs its own profile (`README.md:1112`).
- **xtool backend.** Opt-in: a hermetic LLVM plus a user-supplied `darwin.artifactbundle` for building on Linux. It "cannot build the examples in this repository" because it rejects their storyboards and asset catalog (`README.md:913`, `flutter/settings/apple_backend.bzl:1-12`).

---

## 6. Code generation and localisation

`build_runner` is not used. Generators run as Bazel actions through **rules_dart**: `dart_codegen` writes one output per input and `dart_aggregate_codegen` writes one output from many inputs (`README.md:2188-2222`). Generated files go into the consumer's `srcs`.

| Generator | Support | Source |
|---|---|---|
| `json_serializable` | Curated in ai_rules_dart: the `json_serializable_library` macro and the `@rules_dart//dart/ext/json_serializable:shim` persistent worker. Gazelle can emit it. | `../ai_rules_dart/README.md:483-489`, `../ai_rules_dart/dart/ext/` |
| `freezed` | Curated (`freezed_library`). | same |
| `mockito` (mocks) | Curated. | same |
| `built_value`, `go_router`, `copy_with_extension_gen`, `stacked`, `drift` | Curated. | same |
| `injectable_generator` | **Not curated.** **(Inferred)** It needs a custom `generator_bin`: a `dart_binary` that speaks the shim CLI contract and wraps the `package:build` Builder through rules_dart's generic `builder_shim.dart` (`../ai_rules_dart/docs/ext.md` "Shim contract", "The Resolver"). injectable is also an aggregating builder that needs a whole-package view, so it fits `dart_aggregate_codegen`. | inferred |
| `retrofit_generator` | **Not curated.** It is per-file, so a custom shim plus `dart_codegen` should work **(inferred)**. | inferred |
| `bdd_widget_test` | **Not curated, and nothing in either repo mentions it.** **(Inferred)** Its builder turns `.feature` files into `_test.dart`, which needs a custom generator and a `flutter_test` per generated file. | grep found no reference |
| `flutter gen-l10n` | **First-class `flutter_gen_l10n` rule.** The generator is carved out of `flutter_tools` at fetch time with patches. Outputs land beside the `.arb` files. `l10n.yaml` is **not read** (attributes mirror the CLI flags). The file name and `@@locale` must agree. There is no `format` attribute. Outputs use LF line endings. The app needs `intl` and `flutter_localizations` in its own lock. | `README.md:2224-2266`, `flutter/private/flutter_gen_l10n.bzl:202-258` |

`e2e/codegen` exercises only *custom* generator scripts and `flutter_gen_l10n` (`e2e/codegen/BUILD.bazel:19-80`, `:438-520`); the curated builder macros are tested in ai_rules_dart (`../ai_rules_dart/e2e/ext_exemplar`). Hot reload over regenerated sources works: the dev tool's `refreshGenerated` runs `bazel build` (`docs/TESTING.md:1144-1152`).

---

## 7. Assets, fonts and resources

- **Declaring.** List files explicitly in `assets` on `flutter_library`, `flutter_application` or `flutter_test`. **(Inferred)** First-party `pubspec.yaml` `flutter: assets:` is *not* read; only pub spokes parse pubspecs (`docs/ARCHITECTURE.md:172-189`).
- **Keys.**
  - An app's own asset is keyed by its path relative to the listing package directory. A library asset is keyed `packages/<package_name>/<path>`.
  - A file outside the listing package fails, and so do two files that claim one key.
  - This changed earlier: prefixed keys are gone (`README.md:2074-2080`).
- **Variants.** Any `<number>x` parent directory counts, following flutter_tools 3.47.7 (`docs/pub-assets.md:92-112`).
- **Platform and flavor conditions.** Pub `assets` entries with `platforms` or `flavors` are honoured the way flutter_tools honours them (`README.md:270-274`).
- **Fonts.**
  - Declare `flutter_font_family` targets and list them in `fonts`. App families are bare; library families are prefixed `packages/<pkg>/`.
  - `fonts_json` and `font_files` are deprecated (`README.md:276-304`).
  - Material icons need `@rules_flutter//flutter:material_icons` in `deps` (`README.md:177`).
  - Icon tree shaking is on by default in AOT (`README.md:1748`).
- **Shaders.** Compiled with `impellerc` once per platform through an aspect, not once per consumer (`docs/ARCHITECTURE.md:211-231`, `ai-docs/performance/findings.md:270-289`).
- **App icons.** `AppIcon.appiconset` is found automatically. An `.icon` bundle works on rules_apple 4.5+ (`README.md:1021-1031`).
- **App Intents and extensions.** Passed through to rules_apple. Flutter cannot run inside an extension (`README.md:1033-1114`).
- **Privacy manifests.** Taken from plugins (`flutter_ios_privacy_manifests_gen`).
- **Bundle size limit.** Pub spoke walks are capped at 1,000,000 directories (`docs/pub-assets.md:114-121`).

---

## 8. Testing

**`flutter_test` (widget and unit tests on the host).**

- There is one entry `main` per target (**(inferred)** one target per test file). A generated bootstrap speaks `package:test`'s `RemoteListener` protocol over a WebSocket to `flutter_tester` (`flutter/private/flutter_test.bzl:1-46`).
- Tester flags match `flutter test`: `--use-test-fonts --disable-asset-fonts --enable-software-rendering --skia-deterministic-rendering` (or `--enable-impeller` with `enable_impeller = True`), `--non-interactive` and `FLUTTER_TEST=true` (`flutter/private/tools/flutter_test_runner.dart:560-612`). So text renders in test fonts (Ahem-style) and platform behaviour is that of `flutter_tester`.
- **Compilation is modular:**
  - Each library is compiled once into an outline `.flutter.kmod` and linked per test, so an edit recompiles only that library's module plus the links.
  - The test action's cache key is the kernel, the assets, the runner and the env (`README.md:1861-1865`).
  - On the 30-package bench, kernel-compile CPU fell from 426 s to 28 s plus 68 s in workers (`ai-docs/performance/findings.md:455-468`).
- **Protocol support:**
  - `size` and `timeout` map to Bazel timeouts.
  - `--test_filter` is a regex over full names.
  - `shard_count` splits the suite into contiguous shares.
  - `include_tags` and `exclude_tags` work, and so does `@Tags` on the entrypoint.
  - JUnit `test.xml` is per case.
  - `--test-randomize-ordering-seed` is supported (`README.md:1823-1829`, `flutter/private/tools/flutter_test_runner.dart:84-131`).

**Goldens.**

- They must be in `data`. A missing golden and an undeclared one give the same error.
- Diffs go to `bazel-testlogs/.../test.outputs/failures/`. Regenerate with `bazel run //pkg:test -- --update-goldens`; under `bazel test` that flag exits 64.
- Goldens are host-specific, so commit macOS-generated PNGs only if CI also renders on macOS.
- Replacing `goldenFileComparator` breaks updating (`README.md:1831-1859`).

**Coverage.** `bazel coverage` makes the runner start `flutter_tester` with the VM service and write LCOV, scoped to the test's own package (`flutter/private/flutter_test.bzl:23-25`, `:312-383`).

**Integration tests on the iOS simulator** (`flutter_integration_test(platform = "ios")`):

- The integration test is wrapped as the app entrypoint and built as a `flutter_ios_app` through `ios_sim_debug_app` (JIT). It then boots a simulator, `simctl install`s, writes the harness URL into the app's `tmp/`, launches the app and collects results.
- A run with zero cases fails.
- The test gets a unique bundle id per target and is tagged `exclusive`, so **simulator tests never run in parallel**. It is macOS-only (`README.md:1924-1967`).
- A red twin proves failures are loud (`README.md:1945`).
- **(Inferred)** Every integration-test target builds its own full app (kernel plus bundle).

**`flutter_drive_test`** runs a host `flutter_driver` script against a simulator app. It is `enormous`, `exclusive` and `manual` (`README.md:1969-2035`).

**Plain `bazel test //...` gotcha.** It runs the `dart_analyze` and `dart_format` aspects when `.bazelrc` enables them, and any diagnostic fails the build (`.bazelrc` lines on `--aspects=@rules_dart//dart:analyze.bzl%dart_analyze`; same in `e2e/ios_example/.bazelrc`).

---

## 9. Caching and determinism

| Mechanism | Detail | Source |
|---|---|---|
| Stable URIs | `FlutterKernelCompile` and modules use multi-root `org-dartlang-app:///` URIs, not sandbox `file://` URIs, so dills are byte-identical across machines. | `ai-docs/performance/findings.md:434-438` (plan 2.2) |
| `gen_snapshot --deterministic` | Always passed, and refused if a user passes it again. | `flutter/private/flutter_aot_compile.bzl:26`, `:197-201` |
| Trimmed action inputs | A kernel compile takes about 69 MB of inputs instead of 692 MB. Test runfiles are 13 files / 88 MB instead of 1,062 / 752 MB. | `ai-docs/performance/findings.md:378-395`, `:473` |
| Repository reproducibility | Engine repos return `repo_metadata(reproducible = True)`. CI checks they are shared through the repo contents cache. | `flutter/private/flutter_ios_engine_repo.bzl:131`, `.github/workflows/ci.yaml:1535-1545` |
| Action-shape golden | `flutter/tests/corpus/actions.golden.json` pins the aquery of one fixture per public rule. It is Linux-x64 only. | `flutter/tests/corpus/BUILD.bazel:1-30` |
| Worker identity check | `//tools/incr_kernel_identity` proves the warm worker's dill is byte-equal to a one-shot dill across edits, and asserts *no* cache hit. | `docs/incremental-kernel.md:16-33` |
| Repro canary | `e2e/repro_canary` proves the CI's detection works: a `/dev/urandom` output *must* differ across two output bases. | `.github/workflows/ci.yaml:1485-1525` |

**Known nondeterminism and cache hazards:**

1. **`dev_incremental_serialization` dills** are not byte-identical. They are tagged `no-remote-cache` and `no-remote-exec` (`docs/incremental-kernel.md:52-82`).
2. **The incremental worker route** gives a *different action key* from the stock action. Set `--@rules_flutter//flutter:incremental_kernel=false` when sharing a remote cache in debug (`docs/incremental-kernel.md:55-60`).
3. **"Poisoned" staged-source trees.** A Bazel input-digest race lets an edit during an executing action leave a stale `*.pkgsrcs` tree cached. Fix it by deleting that tree. Upstream asks are recorded for Bazel (`--guard_against_concurrent_changes` for local actions) and for rules_dart (`docs/TESTING.md:1055-1150`).
4. **No test asserts cross-machine cache hits** for iOS actions **(inferred** from grep). The project's own CI dropped its remote cache because it slowed CI (0 remote hits in 5,430 spawns read-only; commit `f2037b1`). It uses per-shard disk caches instead (commit `0525858`).
5. **Signing and `ProcessAndSign`** output is outside these rules. Whether a device `.ipa` is reproducible was not studied **(inferred)**.

---

## 10. Performance and memory

### 10.1 Harnesses

| Tool | What it measures | Source |
|---|---|---|
| `ai-docs/performance/harness/` (`suite.py`, `gen_bench.py`, `prof.py`) | Linux bench: N `flutter_library` packages in a chain, a test per package, Linux and web apps. Scenarios: re-analysis, clean, leaf body or API edit, null build, test run, runfiles, lint. Fixed `-Xmx4g`, `--jobs=8`. | `ai-docs/performance/harness/README.md:40-70` |
| `tools/perf/gen_monorepo.py` | A layered DAG monorepo: `--target-loc` (default 500k), `layers` 8, `fanout` 4, 20 files per package at 100-150 lines, so about 200 packages at 500k. Options `--packages`, `--plugins` (iOS pod, SwiftPM and Android), `--test-ratio`, `--track-widget-creation`. Generator v2 keeps everything reachable for AOT. | `tools/perf/gen_monorepo.py:1-60`, `docs/perf-ios-bench.md:96-123`, `:675-704` |
| `perf-ios.yaml` (`run_rep.py`, `replay.py`, `sol.py`, `ab.py`) | iOS `device_release` (App.framework AOT) and `sim_debug` (full simulator app). Scenarios `clean`, `app_edit`, `core_edit`, `api_edit`. Records action counts, CPU, replayed `time -l`, a "speed of light" hand-replay chain, a toolchain floor, and wall plus **peak RSS** (`peak_rss.py`, the sum of the process tree's RSS sampled every 0.5 s). Same-runner A/B for flags or lockfile. Dispatch only, macos-15, 5 h job timeout. | `docs/perf-ios-bench.md` (whole), `.github/workflows/perf-ios.yaml` |
| `perf-scale-ios.yaml` and `scale_report.py` | 200 and 2,000 packages × 0 and 30 plugins. Fits a growth exponent; the ceiling is **1.5** for every flow. On demand only since `6817f16`. | `tools/perf/scale_ceilings.json`, `docs/perf-ios-bench.md:694-704` |
| `incr_kernel_ab.py`, `attribution*.py`, `warm_server.py` | Worker on/off A/B; CPU split into fetch, module resolution, analysis, sandbox, host tools and target actions. | `docs/incremental-kernel.md:57-60`, `docs/perf-ios-bench.md:706-772` |

### 10.2 Numbers recorded in the repo

| Measurement | Value | Source |
|---|---|---|
| **Warm `frontend_server` (incremental worker) memory** | **about 1.75 GiB per warm server.** Default 1 server per worker. Bound with `--worker_max_instances=FlutterKernelCompile=N`; `INCR_FKC_MAX_SERVERS` raises the cap. | `docs/incremental-kernel.md:144-150`, `flutter/private/tools/incr_fkc_worker.dart:165-189` |
| Modular vs whole-program debug app (Linux, 2 CPU / 8 GB) | Clean 33.2 s / 1,399 MB vs 12.6 s / 1,277 MB. Warm app edit 1.5 s / 1,430 MB vs 4.0 s / 1,270 MB. | commit `bda980b` body |
| Widget-tracking app, 63k lines, 24 packages | Whole-program 20.0 / 18.9 s at 1,345 / 1,296 MB; modular 11.3 / 11.4 s at 1,552 / 1,548 MB. **Peak RSS +17%.** | commit `715b883` body |
| iOS A/B, modular vs whole-program | App-file edit 0.39×, body edit 0.94×, **clean 1.81×** wall. | `docs/adr/0003-kernel-compilation-per-path.md` ("owner had chosen edit-time speed…") |
| iOS 500k `sim_debug` signing | `ProcessAndSign` fell from 3.3-3.6 s to 0.24-0.34 s; warm body edit from 11.0 / 10.7 s to 8.3 / 5.5 s. | commit `48aab37`; `ai-docs/performance/decisions.md` (2026-11-15), run 43597846869 |
| Cold vs warm worker kernel compile (bench app edit) | 20-24 s cold vs 4.5-5.1 s warm. | commit `9ca3b51` |
| Runner noise | Two 100k runs on two macOS runners differed 1.3-1.7× (release clean 108.5 vs 66.9 CPU s). | `docs/perf-ios-bench.md:235-238` |
| Bench durations | 500k × 3 repeats single-arm takes about 95 min. The `sim_debug` clean replay takes 46-54 min because there are hundreds of module spawns. A 20k-line Linux app kernel takes about 80 s. | `docs/perf-ios-bench.md:166-174`, `:308-311`, `:371-373` |
| Linux 30×20 bench, final wave | Clean 80.8 s, body-edit 54.2 s, null 0.18 s, re-analysis (80 packages) 1.23 s, lint clean 106.6 s. Measured on an 8 GiB container at `--jobs=4`. | `ai-docs/performance/findings.md:452-483` |
| `hello_world` debug dill | 53,175,968 bytes, 739 libraries. | `docs/incremental-kernel.md:10-14` |
| `dev_incremental_serialization` | Reset phase 13-16 s with the default vs 1.6 s with the flag (one report). | `docs/incremental-kernel.md:66-68` |
| 16 GB CI runner exhausted | Android Full job: 7.5 GB in use before the build, 15 GB of 16 GB at peak, runner killed. Bounding workers did not lower the peak; 16 GB of swap was added. | `.github/workflows/full.yaml:453-466`, commit `5605359` |
| Disk | Each output base is about 3-4 GB (SDKs plus outputs). | `ai-docs/performance/harness/README.md:66-70` |

### 10.3 What is not measured, and the knobs that exist

**Not measured.** The repo records **no peak RSS for AOT `FlutterKernelCompile` (TFA) or `gen_snapshot` on large apps**. It records no `flutter_tester` memory, no per-`kernel_worker` memory, and no published iOS bench artifacts (artifacts are kept for 3 days and the numbers live only in commit messages). These are exactly the PO's questions, and they are open.

**Memory knobs that exist:**

- `extra_gen_snapshot_options` accepts `--old-gen-heap-size`, `--new-gen-semi-max-size` and related VM heap flags (`flutter/private/flutter_aot_compile.bzl:48-63`).
- `vm_flags` and `resource_set` reach `frontend_server` **only through custom `utils.bzl` rules**. `flutter_application` exposes neither (`README.md:2176`; grep shows `resource_set` only in `flutter/private/flutter_compile.bzl`).
- `--worker_max_instances` for `DartKernel` and `FlutterKernelCompile`.
- `INCR_FKC_MAX_SERVERS`.
- `--@rules_flutter//flutter/private:debug_modular_app=false`.
- `--@rules_flutter//flutter:incremental_kernel=false`.

**Workers in play:**

- `DartKernel` (proto `kernel_worker`, `flutter/private/flutter_kernel_module.bzl:411-415`);
- `FlutterKernelCompile` (JSON `incr_fkc_worker`, `-c dbg` whole-program only, `flutter/private/flutter_compile.bzl:243-246`);
- rules_dart analyzer-summary and codegen-shim workers;
- rules_swift workers.

**Known bottlenecks:**

- AOT is whole-program, so every release edit re-runs the full TFA kernel and `gen_snapshot`.
- The modular debug clean build is 1.8× slower.
- A library reached by both an app and a `flutter_test` in one debug configuration is **compiled twice**, once per aspect (commit `bda980b`).
- Host-tool exec builds (the Swift worker, abseil) are a share of the clean cost (`docs/perf-ios-bench.md:192-197`).
- Without a committed `MODULE.bazel.lock`, every clean build re-evaluates the extensions (`docs/perf-ios-bench.md:313-335`).

---

## 11. Dev workflow

- **Run on the simulator:** `bazel run @rules_flutter//tools/dev_tool:flutter_bazel -- run -t //:app_ios -d ios-simulator`. The dev tool adds `--ios_multi_cpus=sim_arm64` and builds `-c dbg` (`tools/dev_tool/lib/device_ios_sim.dart:71`, `README.md:2331-2410`). `bazel_env.bzl` shortens this to `fl run …` (`README.md:2361-2394`).
- **Hot reload and hot restart work** on the simulator and on devices (`r` / `R`, or on save).
  - The dev tool keeps its **own resident `frontend_server`** outside Bazel and compiles changed libraries (`tools/dev_tool/lib/frontend_server.dart:1-5`).
  - Asset and font edits go live through a devFS diff, and shaders reload (`README.md:2412-2456`).
  - A native-library change makes the dev tool relaunch on restart, and `binding_contract` or `hot_patch` handle native edits on reload (`README.md:492-552`).
  - Codegen apps run a `bazel build` inside reload (`docs/TESTING.md:1144-1152`).
- **Physical devices.** Discovery is over mDNS. lldb stays attached for iOS 26 JIT page breakpoints. Launch takes about 8 s wired and about 40 s over Wi-Fi (`README.md:2464-2491`).
- **IDE.**
  - `--machine` speaks `flutter run`'s JSON-RPC, "so the existing IDE plugins for VS Code and IntelliJ work with it" (`README.md:2329`). There is **no documented VS Code or IntelliJ configuration** (custom Flutter SDK or tool path) **(inferred gap)**.
  - Code navigation relies on `.dart_tool/package_config.json` from `bazel run @rules_flutter//flutter:pub -- get` (`README.md:453`).
  - **(Inferred)** Bazel-generated `.g.dart` and freezed files are not in the source tree, so the IDE analyzer will not see them unless you also run build_runner (rules_dart documents dual-build coexistence, `../ai_rules_dart/docs/ext.md` "Dual-build coexistence").
- **Scripting and agents.** An HTTP control channel offers `/command`, `/logs` and `/screenshot/native`, which can tap widgets, enter text, reload and restart (`README.md:2493-2752`).
- **Profile mode** (`--profile`) runs on devices only.

---

## 12. Lint and analysis (`lint/`)

`lint/BUILD.bazel` is **dev-only for this repo**: one `dart_analysis_config(name = "analysis_config", baseline = "//:analysis_baseline.json", options = ["//:analysis_options"])`, visible only to the root package and aliased as `//:analysis_config` (`lint/BUILD.bazel`, `BUILD.bazel:1-22`). It ships nothing for consumers.

For consumers, analysis comes from rules_dart. Enable `test --aspects=@rules_dart//dart:analyze.bzl%dart_analyze`, `--output_groups=+dart_analyze,+dart_format` and `--@rules_dart//dart:analysis_config=//:analysis_config`. Any diagnostic, down to an info, fails the build (`.bazelrc`, `e2e/ios_example/.bazelrc`). Flutter targets add `sky_engine` so `dart:ui` resolves. Analyzer summaries let a leaf edit re-run 2 `DartAnalyze` actions instead of 61 (`docs/ARCHITECTURE.md:145-157`, `ai-docs/performance/findings.md:477-483`). A layering check on every Flutter program refuses undeclared imports and `dart:mirrors`; turn it off with `-dart_layering_check` (`README.md:1821`).

---

## 13. Contribution and upstream process

- **Issues and PRs.** They welcome bugs, missing SDK features "and slow builds". AI agents read every issue and PR, and the text is treated as data. **PR code never runs on their machines.** Accepted ideas are re-implemented and credited with `Co-authored-by:`. Security reports go to private advisories (`README.md:5-11`, `CONTRIBUTING.md:3-15`, `SECURITY.md`). There are no issue or PR templates in `.github/`.
- **Commits.** Conventional Commits. User-visible changes need a `Changelog:` trailer (one line, present tense, ≤100 characters, no internals; `Changelog: skip` otherwise). Breaking changes use `!`. Checked by `bazel run //tools/changelog:check` and `commit-messages.yaml` (`AGENTS.md`, `CONTRIBUTING.md:37-50`). Agent commits also carry `Agent:`, `Work-Item:` and `Claude-Session:` trailers (`git log`).
- **Formatting gates.** prek runs buildifier, yamlfmt, prettier, typos and the commit-msg check (`CONTRIBUTING.md:17-35`, `.pre-commit-config.yaml`).
- **CI gates.**
  - `ci.yaml` (push and PR, a 7-minute budget, at most 2 macOS jobs): `e2e-macos-apple` (hello_world macOS and iOS), `e2e-macos-toolchain`, `unit-tests`, `flake-sweep`, Linux e2e shards, Windows, `pre-commit`, `dart-tool-tests`, `web-smoke`, `reproducibility`, `repo-checks` (lockfile tidy, e2e coverage, repo contents cache), `last_rc`, `strict`, then `conclusion`.
  - `full.yaml` runs on every main push and nightly: the macOS matrix (plugin_example, integration_ios, drive_ios, ios_example, ios_framework, ios_plugin_matrix, ffi, smoke), the Linux nightly and `dev-tool-ios`.
  - A release requires CI **and** Full green on the commit (`.github/workflows/ci.yaml:129-1646`, `.github/workflows/full.yaml:79-658`, commit `e7c0d45`).
- **Perf evidence culture.** Changes land with A/B numbers (`ai-docs/performance/README.md:28-39`). Perf issues we file should come with `gen_monorepo.py` repro shapes and `peak_rss.py` numbers **(inferred** recommendation).

---

## 14. Known issues, TODOs and limitations

The tree has no `TODO` or `FIXME` in the `.bzl` files (grep). These are the stated or observed gaps, ranked for us:

1. **CocoaPods third-party pods are unbuildable without hand mapping.** Binary-pod and pod-to-SwiftPM resolution are stubs (POD-21, POD-18). Firebase, GoogleMaps, Stripe and MLKit all refuse (`flutter/private/flutter_pub_apple_pods.bzl:68-92`, `e2e/ios_plugin_matrix/expected_pods.json`).
2. **Podspec `vendored_frameworks`, `resources` and `resource_bundles`, and SwiftPM `resources` and `binaryTarget`, are refused.** You need an overlay per plugin (`flutter/private/podspec_read.bzl:186-221`, `README.md:383-385`).
3. **Git pub dependencies are silently skipped**, with only a `print` (`flutter/extensions.bzl:480-485`).
4. **Flutter 3.41.0 is not a stock pin.** CI tests only 3.47.7, and the tools are written for Dart ≥3.13 (`flutter/private/versions.bzl:51`, `flutter/private/tools/pubspec.yaml:6-7`).
5. **The README install block is stale.** It names `ai_rules_flutter` 0.20.0 with `ai_rules_dart` 0.18.0, while the floor is 0.28.3 and the tags are v0.30.x (`README.md:63-78`, `:114`, `MODULE.bazel:129`). The per-release `archive_override` block is generated into the GitHub release notes (`.github/workflows/release_prep.sh:100-215`). `CONTRIBUTING.md:70-80` says the version is a human call, but `auto-release.yaml` now decides it automatically.
6. **The simulator is debug-only.** There is no profile or release check without a device and signing (`README.md:925-941`).
7. **The modular debug path is gated.** Any define, flavor or define file sends a debug app to the whole-program worker, which holds about 1.75 GiB. The modular clean build is 1.81× slower (`docs/adr/0003-kernel-compilation-per-path.md`, `docs/incremental-kernel.md:144-150`).
8. **Double compile** of libraries shared by an app and a test in debug (commit `bda980b`).
9. **The poisoned action-cache race** (a Bazel issue, with upstream asks) (`docs/TESTING.md:1055-1150`).
10. **l10n:** `l10n.yaml` is ignored, the `@@locale` and file name must agree, and there is no format step (`README.md:2254-2262`).
11. **Goldens** are host-specific and must be listed in `data` (`README.md:1844-1859`).
12. **`families` defaults to iPhone only.** iPad needs an icon set without the 76×76@1x icon (`README.md:677`).
13. **The iOS perf bench is dispatch-only** since `6817f16`, so there is no continuous iOS regression signal. Bench artifacts are kept for 3 days.
14. **The xtool backend** cannot build storyboards or asset catalogs (`README.md:913`).
15. **Small gaps:**
    - Android Maven artifacts are not locked (`docs/ARCHITECTURE.md:435-444`).
    - Two private-load exceptions remain in facades (same section).
    - `flutter_plugin` has no `fonts` attribute yet (`README.md:304`).
    - rules_apple 5.2.0 `macos_extension` needs a patch for `app_intents` (`README.md:1104`).

---

## 15. How to consume it from our repo

### 15.1 `MODULE.bazel` (pin to `v0.30.2`)

Use git overrides until we mirror the release archives. Alternatively, take the `archive_override` block with `integrity` from the v0.30.2 GitHub release notes.

```starlark
bazel_dep(name = "ai_rules_flutter", version = "0.30.2", repo_name = "rules_flutter")
bazel_dep(name = "ai_rules_dart", version = "0.28.3", repo_name = "rules_dart")
bazel_dep(name = "rules_apple", version = "5.2.0")      # what upstream's e2e/ios_example uses
bazel_dep(name = "rules_swift", version = "4.1.2")
bazel_dep(name = "apple_support", version = "2.9.1")
bazel_dep(name = "rules_cc", version = "0.2.26")
bazel_dep(name = "platforms", version = "1.1.0")

git_override(
    module_name = "ai_rules_flutter",
    remote = "https://github.com/Mivr/ai_rules_flutter.git",
    commit = "876e263d65ca3eb33e4b05f9b0dc55affc5b3887",  # v0.30.2
)
git_override(
    module_name = "ai_rules_dart",
    remote = "https://github.com/Mivr/ai_rules_dart.git",
    commit = "e7163aab8f9171f54693cd1b99feb7d3cee9602d",  # the pin ai_rules_flutter@876e263 builds with
)

flutter = use_extension("@rules_flutter//flutter:extensions.bzl", "flutter")
flutter.toolchain(flutter_version = "3.41.7")  # nearest stock pin; or flutter.version(...) for 3.41.0, or local_path = "/abs/fvm/versions/3.41.0"
flutter.pub(
    name = "deps",
    lock = "//:pubspec.lock",
    ios_podfile_lock = "//app/ios:Podfile.lock",        # CocoaPods mode, matching our current app
    ios_pod_deps = {
        # "Firebase/CoreOnly": "//third_party/firebase:core",   # one entry per third-party pod
    },
    ios_pod_ignore = [],
)
use_repo(flutter, "deps", "flutter_ios_engine", "flutter_macos_engine", "flutter_toolchains")
register_toolchains("@flutter_toolchains//:all")
```

Sources: `README.md:58-128`, `e2e/ios_example/MODULE.bazel`, `e2e/integration_ios/MODULE.bazel:70-100`. `MODULE.bazel:177-181` gives the ai_rules_dart commit.

### 15.2 `.bazelrc`

```bazelrc
# Required (README.md:130-145)
common --tool_java_language_version=25
common --tool_java_runtime_version=remotejdk_25

# Analysis as upstream's e2e workspaces wire it (e2e/ios_example/.bazelrc)
test --aspects=@rules_dart//dart:analyze.bzl%dart_analyze
test --output_groups=+dart_analyze
test --output_groups=+dart_format
common --@rules_dart//dart:analysis_config=//:analysis_config

# Our configs (proposals, (inferred))
build:sim     -c dbg --ios_multi_cpus=sim_arm64
build:device  -c opt --ios_multi_cpus=arm64
build:profile -c opt --@rules_flutter//flutter:profile   # README.md:204
# 16 GB laptop guard rails, to validate in profiling (section 16)
build:laptop --worker_max_instances=FlutterKernelCompile=1 --worker_max_instances=DartKernel=2
build:laptop --local_resources=memory=HOST_RAM*.6
common --disk_cache=~/.cache/bazel-disk
try-import %workspace%/.bazelrc.user
```

Also commit `MODULE.bazel.lock` (`docs/perf-ios-bench.md:313-335`).

### 15.3 Xcode and host setup

- Install Xcode and a simulator runtime. If an Xcode beta breaks `local_config_xcode`, set `--repo_env=DEVELOPER_DIR=…` (`docs/TESTING.md:651`).
- Keep `ios/Runner/` from `flutter create --platforms=ios`. Put `flutter_ios_app` in the package that holds `ios/Runner/` (`README.md:661`, `README.md:1106`).
- For devices, add `local_provisioning_profile` in a git-ignored `//device` package and pass `entitlements = False` if the profile lacks push (`README.md:819-884`).
- A host `python3` is needed for device screenshots and the tunnel (`MODULE.bazel` closing comment).

Each `flutter_application` must set `package_name` to the pubspec `name` and include `@rules_flutter//flutter:material_icons` (`README.md:174-177`).

---

## 16. Implications and risks for a 1M LOC, 100+ package Flutter iOS monorepo on 16 GB laptops

### 16.1 Structural risks

1. **Native dependency effort dominates the migration.** Every non-trivial CocoaPod needs a hand-written Bazel target plus an `ios_pod_deps` entry, and plugins with podspec `resources` or vendored frameworks need overlays (section 4). Budget per-plugin work, and consider moving those SDKs to SwiftPM pins with `swift_package_sha256`.
2. **SDK version mismatch.** We use 3.41.0; the rules are tested on 3.47.7 and their tools expect Dart ≥3.13. Either upgrade Flutter as part of the migration or prove the 3.41 path early (H-SDK).
3. **No Flutter-aware BUILD generator.** ai_rules_dart's gazelle has no `flutter_*` kinds (grep of `../ai_rules_dart/gazelle/dart/*.go`). For 100+ packages we need `map_kind` or our own generator **(inferred)**.
4. **Default `bazel build //...` is AOT** (fastbuild means release). Every `flutter_application` that `//...` reaches AOT-compiles for the host **(inferred** from `flutter/private/flutter_application.bzl:550-560`). That is costly and memory-heavy at 1M LOC. Tag apps `manual` or use `--config=sim` locally.
5. **Our app likely has flavors and `--dart-define`s.** Those push debug builds off the modular path and onto the whole-program warm worker. So the modular edit-time wins may never apply to us (ADR-0003 eligibility).
6. **Alpha churn.** There are daily releases and breaking `!` commits. Pin a commit and gate upgrades behind our own bench.

### 16.2 Profiling hypotheses (each is testable with upstream's `tools/perf` and `peak_rss.py`)

| ID | Hypothesis | How to test |
|---|---|---|
| H-SDK | The rules' Dart tools (`flutter/private/tools`, `tools/dev_tool`) fail to compile under Flutter 3.41.x's bundled Dart. Registering a newer standalone Dart toolchain first fixes it. | `bazel build @rules_flutter//flutter/private/tools:all` with `flutter_version = "3.41.7"` and with a `local_path` 3.41.0 SDK. |
| H-AOT-1 | At 1M LOC, the whole-program AOT `FlutterKernelCompile` (TFA) peaks at roughly 4-8 GB RSS and `gen_snapshot` at roughly 3-6 GB **(inferred)**. Two flavors or apps in one `bazel build` can run them concurrently and exceed 16 GB. | `gen_monorepo.py --target-loc 1000000`; `bazel build -c opt --ios_multi_cpus=arm64 //app:__app_framework_framework` under `peak_rss.py`; repeat with 2 apps at `--jobs` auto vs `--local_resources=memory=…`. |
| H-AOT-2 | `extra_gen_snapshot_options = ["--old-gen-heap-size=…"]` caps `gen_snapshot` RSS without changing snapshot bytes. | A/B the same target and compare the App.framework sha256 and peak RSS. |
| H-JIT-1 | The whole-program debug path holds about 1.75 GiB per warm server at hello_world scale and grows with program size, perhaps 4-6 GB at 1M LOC **(inferred)**. On top come the Bazel JVM (default heap is about a quarter of RAM), the dev tool's own resident `frontend_server`, the Simulator and the IDE analysis server. Together they push a 16 GB laptop into swap during a hot-reload session. | Run `flutter_bazel run -d ios-simulator` on the 1M bench and sample the whole tree (Bazel server plus dev tool plus Simulator) with `peak_rss.py`. |
| H-JIT-2 | On the modular debug path, the default `DartKernel` worker count multiplies the resident platform dill and outlines per worker. Peak RSS is bounded by `--worker_max_instances=DartKernel=2` with little loss in clean wall time. | A/B through `perf-ios.yaml` `bazel_flags` with `ab=flags`. |
| H-JIT-3 | At 400+ modules, modular clean builds are more than 2× slower than whole-program (1.81× measured at 500k), while edits are about 0.4× (app layer) and about 0.9× (core layer). | `sim_debug` flows, `debug_modular_app=true` vs `false`, 1M LOC. |
| H-TEST-1 | Thousands of `flutter_test` targets (one per file) cost more in per-test link plus `flutter_tester` startup than in compile. Running parallel `flutter_tester`s at the default `--local_test_jobs` exceeds 16 GB. | `gen_monorepo.py --test-ratio`; time `bazel test //packages/...` with `--local_test_jobs` 4, 8 and auto; measure peak RSS. Consider `flutter_prebuilt_test` aggregation. |
| H-TEST-2 | Libraries shared by the app and tests in `-c dbg` are compiled twice (once per aspect). Running tests in fastbuild and the app in dbg avoids that, but costs a second configuration. | Count `DartKernel` spawns in the execution log for `bazel test -c dbg //...` plus a simulator build. |
| H-CACHE | `DartKernel`, `FlutterKernelCompile` (stock route) and `FlutterAotMacho` outputs are byte-identical across two clones at different absolute paths. The incremental-worker route is not shareable. | Build in two output bases or clones, compare digests, and check `--disk_cache` hit rates. |
| H-ANALYSIS | Analysis-phase memory and time grow super-linearly with 100+ first-party packages plus a few hundred pub spokes. The exponent ceiling is 1.5 upstream. | `perf-scale-ios.yaml` shapes at 200, 2,000 and our package count; `bazel build --nobuild` with `--memory_profile`. |
| H-ITEST | Each iOS `flutter_integration_test` builds its own full app and runs `exclusive`, so N integration files cost about N full app builds plus serial simulator runs. | Build 10 integration targets and count `ios_application` actions and wall time. |
| H-PODS | CocoaPods-mode fetch of our real `Podfile.lock` fails on unmapped pods. The number of `ios_pod_deps` entries we need equals the number of distinct non-plugin pods in our lock. | Run `bazel query @deps__<plugin>//:all` over our plugin list, as `e2e/ios_plugin_matrix/run_pods_matrix.py` does. |

**Bottom line (inferred).** The rules look technically strong and unusually well instrumented. For our app the risk is not correctness of the Dart pipeline but three things: native dependency coverage, the Flutter version gap, and unmeasured AOT and JIT memory at 2× the largest benchmark they run (500k LOC). Upstream welcomes slow-build issues, so the hypotheses above are what we should measure first and report.
