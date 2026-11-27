# mini-client

[![CI](https://github.com/emiliev/mini-client-application/actions/workflows/ci.yml/badge.svg)](https://github.com/emiliev/mini-client-application/actions/workflows/ci.yml)

An enterprise Marvel app in the Tide "Project Miniclient" architecture, built with Bazel. Project knowledge lives in [`documents/`](documents/README.md); agents start with [`CLAUDE.md`](CLAUDE.md).

## Developing

Bazel builds, tests and CI. Nothing generated is committed (freezed, json, retrofit, injectable, go_router, gen-l10n), so a fresh checkout shows errors in the IDE and cannot `flutter run`. `tool/ide_sync` fixes that: it asks Bazel for the generated Dart and copies it next to the sources. The copies are git-ignored and Bazel never reads them (builds and tests are byte-identical with and without them).

### First run

```sh
fvm install                               # Flutter 3.47.7 (.fvmrc)
tool/ide_sync --env dev                   # codegen into the tree, config asset, Xcode project, pub get
# open the repo in the IDE (Dart SDK / Flutter SDK path: .fvm/flutter_sdk)
cd app/mini_client
fvm flutter run -d <simulator id>         # `xcrun simctl list devices booted`
```

`flutter run` gives breakpoints and hot reload on the real checkout. `--env` picks `tool/bazel/config/<env>.json` (`dev`, `e2e`, `perf`) as `assets/app_config.json`; Bazel bundles the same file with `--//tool/bazel/config:env=<env>`.

### Watch mode

```sh
tool/ide_sync --watch --env dev           # in a second terminal, next to `flutter run`
```

It syncs again within a few seconds of saving a Dart, ARB, `pubspec` or `BUILD.bazel` file (`fswatch` if installed, else polling every second). `flutter run` then picks the new generated file up on its next `r` (hot reload) or `R` (hot restart).

### What to re-run after which change

| You changed | Run |
|---|---|
| A freezed/json/retrofit/injectable/go_router source, an ARB, a BUILD codegen target | `tool/ide_sync` (or keep `--watch` running), then `r` in `flutter run` |
| Only function bodies, widgets, styles | Nothing: hot reload |
| `pubspec.yaml` of any package | `tool/ide_sync` (it runs `fvm flutter pub get`), then restart `flutter run` |
| Switched branch | `tool/ide_sync` (stale generated files of the old branch are deleted via `.dart_tool/mc_ide_sync.manifest`) |
| One package only | `tool/ide_sync feature/characters/characters_list` |
| Want the tree free of what ide_sync wrote | `tool/ide_sync --clean` (generated Dart, config asset and the Xcode scaffolding it created; not gen-l10n, which `flutter pub get` writes and `git clean -fdX` removes, nor `Pods/` or `build/`) |

Other options: `--link` (symlinks into the Bazel output base instead of copies), `--no-pub`. `tool/ide_sync --help` lists them all.

### Bazel stays the source of truth

```sh
tool/bazelw test //...                    # all tests
tool/bazelw build --config=sim //app/mini_client:mini_client_ios
```

A new package that has codegen must exclude the synced files in its `glob(["lib/**/*.dart"])`: `exclude = MC_GENERATED_DART` (from `//tool/bazel:defs.bzl`). `tool/checks/T-0042-AC4_safety.sh` fails when a glob picks up a synced file.
