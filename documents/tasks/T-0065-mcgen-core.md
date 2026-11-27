# T-0065: `tool/mcgen` core: spec model, seeded RNG, writer, manifest, keep regions, `gen --check` (P2-01)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (**Opus**: novel generator design that every later template builds on; ADR-0011) |
| Verification | ADR-0015: `/code-review`, one fix round, TL merge gates. No Verifier, because this is not one of the exceptions. |
| Branch | `fleet/T-0065-mcgen-core` |
| Created | 2026-11-27 |
| Depends on | Phase C complete (7 exemplars), `tool/loc` (D8) |
| Related | plan 02 §2.1, §2.2, §2.4, §2.5, §2.6, §2.7, §7.1, P2-01; plan 01 D-rules; ADR-0009; ADR-0015; F-0021 (pub get rewrites the Flutter `analysis_options.yaml`); P-117 (non-workspace tool packages) |

## Goal
Build the core of the generator that will produce the remaining ~95 features from short specs. This task delivers the **machinery only**. The per-archetype templates (P2-04 to P2-07) come next and build on it.

## Scope
- **In: `tool/mcgen/{bin,lib/src/core,schema,test}`.**
  - **Packaging.** `mcgen` is a Dart CLI run with `fvm dart run tool/mcgen`. Its pub dependencies stay isolated from the app's resolution (plan 02 §2.1), for example as a standalone package with its own lockfile, as `tool/loc` is.
    - Fix P-117 in a way that works for both: a nested `.dart_tool` must not break the format gate.
    - `mason` is **not** in the offline pub cache, while `mustache_template` and `dart_style` are. Either fetch `mason` online and commit the lockfile, or render bricks with `mustache_template` directly in the mason brick format (`brick.yaml` plus a `__brick__/` tree) so `mason make` still works for humans. Decide, and record the choice in a finding.
    - Add a Bazel `dart_binary` or test target only if the isolated hub works cleanly. Otherwise write down why not.
  - **Spec model (`mcgen/1`).**
    - The YAML spec per module from plan 02 §2.2: module, tier, archetype, size class, ownership, seed salt, deps, entities (fields, enums, unions), endpoints, screens, flow, navigator, l10n, bdd, rules.
    - A committed JSON Schema in `tool/mcgen/schema/mcgen-1.json`.
    - A typed Dart model that loads it with precise errors (file:line).
  - **`mcgen spec lint`.** Schema validation plus semantic checks:
    - D1 layering (no feature→feature deps);
    - `mc_design_system` is never a direct dep;
    - name collisions;
    - the scenario-ID format;
    - examples present for every rule.
  - **Determinism (§2.5).**
    - `SplitMix64` seeded by `fnv1a64("$globalSeed/$module/$seedSalt")`, with named forked streams (`rng.fork('entities').fork('Character')`). Never `dart:math` `Random`.
    - Byte stability: sorted by code unit, LF only, no timestamps or absolute paths, and formatted with the FVM-pinned `dart format` (3.47.7), so output matches the repo's format gate.
  - **Writer, manifest and ownership (§2.6).**
    - `.mcgen/manifest.json` records the generator version, spec hash, seed, and each file's hash and ownership.
    - Ownership modes:
      - `managed`: only keep regions may be edited by hand;
      - `mixed`: `owned:` files are written once;
      - `ejected`: nothing is written.
    - Keep regions take the form `// mcgen:keep <id>` … `// mcgen:end <id>`, only inside bodies. Their content is preserved verbatim, and a region's default body is emitted only when the region is new.
    - **Clobber guard:** before writing, compare each file's hash with the manifest, ignoring keep-region content. On a mismatch, stop and list the drifted files. `--force` overrides.
    - The header comment on managed files follows §2.6.
  - **Emitter foundation (§2.4).**
    - A small typed IR for Dart declarations and imports.
    - A **symbol table**, where every emitted declaration registers its owning file.
    - An **import resolver** that writes exactly the imports in use, as `package:` imports sorted for `directives_ordering`.
    - The same use-graph yields a package's pubspec and BUILD `deps` (the BUILD output itself comes in P2-08).
  - **Commands working end to end:**
    - `mcgen spec lint`;
    - `mcgen gen <module>… [--check]`, where `--check` is a dry run that exits 1 on any diff;
    - `mcgen check` (drift: hand edits in managed files, stale manifests, keep-region damage).

    `spec synth`, `wire`, `buildgen`, `owners`, `new`, `synth` and `stats` are stubs that exit non-zero with "not yet (P2-xx)".
  - **A tiny reference archetype for testing the core**, for example `utility_hello`: a 3-file package (pubspec, barrel, one class) produced by one brick and one emitter. It is **not** one of the 7 exemplars; those come in P2-04 to P2-07.
- **Out:**
  - the real archetype templates (P2-04 to P2-07);
  - `mcgen wire`/`buildgen` (P2-08);
  - shape/realism (P2-09);
  - spec synthesis (P2-xx).

## Acceptance criteria
- **T-0065-AC1 (P2-01 AC1):**
  - Given the reference spec, `mcgen gen` runs twice into two directories with different absolute paths. The two trees are byte-identical.
  - A second run reports no writes, and `--check` exits 0. After a template change, `--check` exits 1 and lists the file.
- **T-0065-AC2 (keep regions and clobber guard):**
  - A hand edit inside a keep region survives regeneration, byte for byte.
  - A hand edit outside one stops `gen` with a drift report naming the file. `--force` overwrites it and logs that it did.
  - In `mixed` mode an `owned:` file is written once and never again. In `ejected` mode nothing is written.
  - `mcgen check` reports each of the three drift kinds.
- **T-0065-AC3 (determinism and RNG):**
  - A golden table of `SplitMix64` and `fnv1a64` values, computed independently in the test.
  - Forking is stable: adding a new fork doesn't change the values of existing forks.
  - The same seed gives identical output across runs and machines: the test runs under two working directories and asserts no absolute paths.
- **T-0065-AC4 (spec and lint):**
  - The schema accepts the plan 02 §2.2 example spec.
  - Each lint rule rejects a crafted bad spec, with a precise message and line.
- **T-0065-AC5 (imports and format):**
  - Emitted Dart passes `dart analyze` with `mc_analysis` and has zero diagnostics.
  - Imports are exactly the ones in use: no unused or missing import, shown by a test that adds and removes a reference.
  - The output passes the format gate.
  - `test --lockfile_mode=error //...` stays green, and the app's lockfiles are unchanged.
  - A finding is written: `F-0065-mcgen-core.md`.

## Log
- 2026-11-27: Created and dispatched (TL). PO chose the hybrid approach: the generator in parallel with hand-built features.
