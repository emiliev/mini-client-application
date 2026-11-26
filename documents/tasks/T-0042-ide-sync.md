# T-0042: `tool/ide_sync`: generated code in the checkout for the IDE, `flutter run` and debugging (P3-10)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (tooling; ADR-0011) |
| Branch | `fleet/T-0042-ide-sync` |
| Created | 2026-11-26 |
| Depends on | T-0014 (Bazel toolchain), T-0033 (`prepare_pub_project.sh`, which already finds the codegen outputs with `cquery`) |
| Related | plan 03 KD11 and §7.1, P3-10, P-044, R10, R13, R28, F-0021, F-0032 |

## Goal
Bazel generates all codegen into `bazel-bin/`, and nothing generated is committed (R10). As a result, the IDE analyzer shows errors on every generated part, and `fvm flutter run`/debug against the repo doesn't work. `tool/ide_sync` copies exactly the Bazel-generated files next to their sources, git-ignored, so that the IDE, `flutter run`, breakpoints and hot reload all work on the real checkout. Bazel stays the source of truth for builds, tests and CI.

## Scope
- **In:**
  - `tool/ide_sync [--watch] [--link] [--env <env>] [<package>...]`, as in plan 03 §7.1:
    1. Build every codegen target, or the ones for the named packages. Add an aggregate target `//:all_codegen` if it helps.
    2. List the outputs with `cquery --output=files`, reusing the approach in `prepare_pub_project.sh`.
    3. Copy each output to `<pkg>/<rel>` only if its bytes differ.
    4. Delete files from the previous `.dart_tool/mc_ide_sync.manifest` that are no longer produced.
    5. With `--env`, write `app/*/assets/app_config.json` (R13).
    6. Make sure `fvm flutter pub get` works and `flutter run` can start `app/mini_client` from the checkout.
    7. `--watch` re-syncs on source changes, using `fswatch` if present and polling otherwise.
    8. `--link` uses symlinks, as an A/B option.
  - Guards:
    - `.gitignore` covers every synced path, and **no synced file can be committed**: a check fails if one is tracked.
    - BUILD globs exclude the synced suffixes, so `bazel build` and `test` are byte-identical with and without a sync.
    - Never write a path listed in the R28 fallback manifest.
  - Docs: a short "Developing" section in the root README (or `documents/`) covering:
    - first run (`tool/ide_sync --env dev`, then open in the IDE, then `fvm flutter run -d <simulator>`);
    - watch mode;
    - what to re-run after which change.
  - Optional, if cheap: make `tool/e2e/prepare_pub_project.sh` reuse `ide_sync`'s output listing.
- **Out:** a Bazel-native JIT and hot-reload loop (Phase F, P4-12) and IDE plugins.

## Acceptance criteria
- **T-0042-AC1:** On a fresh clone, after `tool/ide_sync --env dev`, `fvm dart analyze` (or `fvm flutter analyze`) over the workspace packages reports **zero** errors about missing generated parts. Before the sync it reports them; show both runs.
- **T-0042-AC2:** After the sync, `fvm flutter run -d <own simulator>` (or `flutter build ios --simulator`) for `app/mini_client` starts from the checkout. A screenshot shows the home screen. The simulator is your own and is deleted afterwards.
- **T-0042-AC3:** Incremental and stale handling:
  - A second sync with no source change copies 0 files; mtimes are unchanged.
  - Editing one freezed model re-copies only that model's outputs.
  - Removing a model deletes its synced outputs (manifest).
  - `--watch` picks up an edit within 5 s.
- **T-0042-AC4:** Safety:
  - `git status --porcelain` is clean after a sync (everything ignored).
  - A check fails if any synced output is tracked, or if a BUILD glob would pick one up. Give it a negative control.
  - `bazel test //...` and the T-0032 byte-identity check pass with synced files present, and the build's outputs are identical to a run without them.
- **T-0042-AC5:** Gates: `test //...`, lint, `mc_arch_check`, `rules_fork.sh check` and format all pass, and the script has tests: a shell test or a Dart test of its core, with fixtures.

## Log
- 2026-11-26: Created and dispatched (TL). The PO asked how to build, debug and run when generated code isn't in the repo.
