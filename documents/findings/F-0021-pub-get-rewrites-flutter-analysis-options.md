# F-0021: `flutter pub get` rewrites a Flutter package's `analysis_options.yaml`, and a per-package file drops the root formatter setting

- **Date:** 2026-11-24
- **Author:** crew: Engineer (T-0021)
- **Type:** Gotcha
- **Related:** plan 01 §3.1 (one-line `analysis_options.yaml`), F-0013 fact 4, T-0021

## Summary
1. **`fvm flutter pub get` (3.47.7) edits Flutter packages.** For every workspace member that depends on the Flutter SDK and has its own `analysis_options.yaml` without a `build/` exclude, it prints `Upgrading analysis_options.yaml to exclude build and platform directories.` and rewrites the file to
   ```yaml
   analyzer:
     exclude:
       - build/**
   include: package:mc_analysis/analysis_options.yaml
   ```
   Pure-Dart members (`mc_config`, `mc_di`, …) are left alone. Existing Flutter utilities (`mc_ds_*`) never hit this, because they have no `analysis_options.yaml` of their own.
2. **A per-package options file also loses the root `formatter: trailing_commas: preserve`.** That setting is per project and isn't inherited through `include:` (the root file says so). A package with its own one-line file is therefore formatted in a different style from the rest of the repo.

## What T-0021 did
`app/wiring/*` and `app/mini_client` have **no** `analysis_options.yaml`, like `mc_ds_*`. The root file applies: the mc_analysis rules plus the shared formatter setting. Bazel's `//:analysis_config` lists only the root options, so the lint aspect is unaffected.

## Implications
- Plan 01 §3.1 says "`analysis_options.yaml` is one line". For Flutter packages that line gets rewritten on every `pub get`, so `mcgen` / mason bricks (P1-24) should leave the file out (or emit the rewritten form plus `formatter:`).
- Pure-Dart packages that keep the one-liner format without `trailing_commas: preserve`. That works today; P1-01 should decide whether it's intended.
