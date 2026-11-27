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
- 2026-11-27 (Engineer, Opus):
  - Branch `fleet/T-0065-mcgen-core` from `origin/main` @ `16b26bf`.
  - **Packaging:** standalone pub package with its own lockfile. It resolved offline, so mason was not fetched.
  - **Renderer:** mustache_template in mason's brick format.
  - **Formatter:** the pinned SDK's `dart format`, run as a subprocess. The cache has no `dart_style` 3.1.13.
  - **No Bazel target:** an isolated hub would change `MODULE.bazel.lock`.
  - Reasons in F-0065 §1 to §3; the costly-to-reverse formats are in ADR-0016 (Proposed).
  - **P-117 root-caused** (two causes, not one) and fixed for tool/loc and tool/mcgen (F-0065 §4).
  - Mid-task correction: I first rendered with `htmlEscapeValues: false`. Reading mason's `render.dart` showed that mason keeps mustache's default escaping, so mcgen now does too, and templates use `{{{x}}}`.

## Outcome
**Handed off** for `/code-review` and the TL merge gates (ADR-0015, no Verifier). Finding: [F-0065](../findings/F-0065-mcgen-core.md). ADR draft: [ADR-0016](../adr/0016-mcgen-spec-manifest-and-determinism.md) (Proposed). Evidence: [`documents/evidence/T-0065/`](../evidence/T-0065/).

### What was built
- **`tool/mcgen`**, a standalone Dart package:
  - its own `pubspec.lock` (args, crypto, mustache_template, path, yaml, test), resolved offline;
  - `analysis_options.yaml` (it includes nothing; see P-117);
  - `mcgen.yaml` (global seed 20261127, the pinned formatter 3.1.13, third-party constraints);
  - `README.md`.
- **`lib/src/core/`:**
  - `spec/` holds the JSON Schema subset validator (it runs over YAML nodes, so errors carry line and column), the typed `mcgen/1` model and loader, and the type and signature parsers;
  - `lint.dart`: D1 layering, `mc_design_system`, unknown deps, name collisions, scenario ids, rule examples, ownership, archetype and tier;
  - `rng.dart`: fnv1a64, SplitMix64, named forks;
  - `ir/`: Code with `ref()` markers, the declaration IR with `Keep` only in bodies, the symbol table, the import resolver and renderer, the use-graph;
  - `brick.dart`, `format.dart`, `emit.dart` (EmitContext, PackageCatalog), `generator.dart`;
  - `writer.dart`: plan and apply, the clobber guard, ownership;
  - `manifest.dart`, `keep.dart` (the loc-compatible hash), `check.dart`;
  - `roundtrip.dart`: the KD1 harness for P2-04 to P2-07;
  - `naming.dart`, `repo.dart`, `config.dart`, `diagnostics.dart`.
- **`lib/src/cli.dart` and `bin/mcgen.dart`:** `spec lint`, `gen [--check] [--force] [--out]` and `check` work end to end. `spec synth`, `wire`, `buildgen`, `owners`, `new`, `synth` and `stats` exit 3 with `not yet (P2-xx)`.
- **The reference archetype `utility_hello`:**
  - `lib/src/emit/utility_hello/` and `bricks/utility_hello/` (the pubspec brick);
  - `lib/src/archetypes.dart` is the registry;
  - its spec is `test/fixtures/utility_hello/mcgen.yaml`, and its expected output is `test/golden/utility_hello/` (formatted by the repo gate, since it is under `tool/`).
- **`schema/mcgen-1.json`.**
- **P-117:** `tool/loc/analysis_options.yaml` (new) and `tool/loc/pubspec.yaml` `sdk: ^3.13.0` (was `^3.11.0`). tool/loc's lockfile is unchanged.
- **`tool/checks/T-0065-AC5_gates.sh`:** mcgen's gates, which Bazel does not run (F-0065 §1).

### AC → evidence
Tests are in `tool/mcgen/test/` and run with `cd tool/mcgen && fvm dart test`: 80 tests, all passing. 10 consecutive runs gave 80/80 each ([`mcgen-test-10-runs.log`](../evidence/T-0065/mcgen-test-10-runs.log)).

| AC | Tests and evidence |
|---|---|
| AC1 | `gen_test.dart`: "T-0065-AC1 two roots with different absolute paths give identical trees, equal to the golden"; "T-0065-AC1 a second run reports no writes, and --check exits 0"; "T-0065-AC1 after a template change, --check exits 1 and lists the file"; "T-0065-AC1 after a spec change, --check lists exactly the files that change". `cli_test.dart`: "T-0065-AC1 the reference golden round-trips exactly"; "T-0065-AC1 an exemplar without the header and with other keep bodies still matches". `brick_test.dart`: "T-0065-AC1 standalone section lines vanish (mustache spec)"; "T-0065-AC1 missing, undeclared and unknown variables are errors"; "T-0065-AC1 the utility_hello brick is a valid mason brick" |
| AC2 | `gen_test.dart`: "T-0065-AC2 a hand edit inside a keep region survives regeneration byte for byte"; "T-0065-AC2 a hand edit outside a keep region stops gen, names the file and writes nothing"; "T-0065-AC2 --force overwrites a drifted file, keeps its regions, and logs it"; "T-0065-AC2 damaged keep markers stop gen"; "T-0065-AC2 mixed: an owned file is written once and never again"; "T-0065-AC2 ejected: nothing is written"; the three drift kinds of `mcgen check`: "T-0065-AC2 hand-edit", "T-0065-AC2 stale-manifest: the spec changed, or the module was never generated", "T-0065-AC2 keep-damage: an end marker removed, a region removed"; "T-0065-AC2 keep-region lines count as hand, the rest as scaffold" (tool/loc on mcgen output). `keep_test.dart`: "T-0065-AC2 reports each kind of damage with its line"; "T-0065-AC2 carries old bodies into new output verbatim; new regions get defaults" |
| AC3 | `rng_test.dart` (each value in the golden table is also recomputed by an independent BigInt implementation): "T-0065-AC3 fnv1a64 matches the table and the BigInt reference"; "T-0065-AC3 SplitMix64 matches the table and the BigInt reference"; "T-0065-AC3 the module seed is fnv1a64 of "globalSeed/module/salt""; "T-0065-AC3 a fork is mix(parent seed ^ fnv1a64(name))"; "T-0065-AC3 adding a fork does not change existing forks"; "T-0065-AC3 drawing from a parent does not change its forks". `determinism_test.dart`: "T-0065-AC3 same seed, two working directories and environments: identical bytes, no absolute paths" (two separate VMs, different working directories, TZ and LANG); "T-0065-AC3 a different seed salt re-rolls the seeded choice, and only that" |
| AC4 | `spec_test.dart`: "T-0065-AC4 accepts the plan 02 section 2.2 example spec" (`test/fixtures/plan02_example.yaml` is copied verbatim from the plan); "T-0065-AC4 against the real repo, only the archetype is unknown (P2-04 adds list_detail)". One test per lint rule, each asserting the exact `file:line:col: error [rule] yamlPath: message`: "T-0065-AC4 D1 layering: feature -> feature"; "T-0065-AC4 D1 layering: utility -> feature, also through dev_deps"; "T-0065-AC4 mc_design_system is never a direct dep"; "T-0065-AC4 an unknown dependency"; "T-0065-AC4 name collisions: types, fields, ids, and the module itself"; "T-0065-AC4 name collisions: endpoint and rule ids, navigator methods"; "T-0065-AC4 scenario ids: format and uniqueness"; "T-0065-AC4 every rule needs examples"; "T-0065-AC4 archetype, tier and ownership rules"; "T-0065-AC4 schema errors carry file, line, column and YAML path"; "T-0065-AC4 a YAML syntax error is located" |
| AC5 | `imports_test.dart`: "T-0065-AC5 dart analyze with mc_analysis reports zero diagnostics", with its control "T-0065-AC5 control: the analysis really runs mc_analysis (an unused import is caught)"; "T-0065-AC5 adding a reference adds its import; removing it removes the import"; "T-0065-AC5 removing the reference in the spec removes the import, and stays clean"; "T-0065-AC5 directives follow directives_ordering"; "T-0065-AC5 the output is formatted as the format gate formats (no change)"; "T-0065-AC5 the committed golden equals the output, so the repo gate formats it too"; "T-0065-AC5 the pubspec dependencies come from the use-graph". Gates: [`T-0065-AC5_gates.md`](../evidence/T-0065/T-0065-AC5_gates.md) (PASS: the format gate with nested `.dart_tool` in tool/mcgen and tool/loc, `dart analyze`, `dart test`, the app's lockfiles unchanged against `origin/main`). `tool/bazelw test --lockfile_mode=error //...`: 223/223 pass ([`test-lockfile-error-bazel.log`](../evidence/T-0065/test-lockfile-error-bazel.log)). Finding: F-0065 |

### Gates
| Gate | Result |
|---|---|
| `tool/bazelw --output_base=/tmp/mc-ob-T-0065-engineer test --lockfile_mode=error //...` | 223 tests pass, exit 0. All were cached: no Bazel input changed, since mcgen is not a Bazel package |
| Shared format gate, `tool/checks/lib/format_gate.sh` | 0 changed, with nested `.dart_tool` in tool/loc and tool/mcgen (P-117) |
| `cd tool/mcgen && fvm dart analyze --fatal-infos` | No issues |
| `cd tool/mcgen && fvm dart test` | 80/80, ten runs in a row |
| `pubspec.lock`, `MODULE.bazel.lock` | unchanged against `origin/main` |

### Test integrity
- No test was deleted, skipped or weakened, and nothing carries `// ignore:`.
- The generator never emits `// ignore`.
- The only golden is the new `tool/mcgen/test/golden/utility_hello/`. It is tooling, not a feature, so ADR-0015's ban on feature goldens doesn't apply.

### Extension points for P2-04 to P2-07
F-0065 §5 has the details:
- `Archetype` (`name`, `tiers`, `lint`, `emit`), registered in `lib/src/archetypes.dart`;
- `EmitContext` (`library`, `file`, `brick`, `deferred`, `owned:`, `rng.fork`);
- the IR, with `Keep` only in bodies;
- symbols (`ctx.symbols.external`, `ref(name, from:)`);
- `UseGraph` for pubspec and BUILD deps;
- `PackageCatalog`;
- `compareToExemplar` for the round-trip golden (P2-04 adds keep markers to its exemplar);
- `doc:` fields and `DartLibrary.preamble` for byte-exact prose;
- `spec.options` for archetype-only settings.

### Follow-ups (for the TL's pending-work)
- **Bricks with `.dart` templates (P2-04) will break the format gate** unless the gate skips `__brick__/` directories, or the template file names don't end in `.dart` (F-0065 §2).
- **A shared table of the first-party kits' exported symbols**, so archetypes don't each register `McBloc`, `FeatureFlow`, etc. (F-0065 §5.4).
- **`test //...` does not run mcgen's tests.** The TL runs `tool/checks/T-0065-AC5_gates.sh` with the merge gates, until a tool hub in `MODULE.bazel` is acceptable (F-0065 §1).
- **The writer leaves empty directories behind** when a spec stops generating every file in one. This is cosmetic.
