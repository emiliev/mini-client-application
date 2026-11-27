# F-0065: The mcgen core: packaging, renderer and formatter decisions, P-117's root cause, and how an archetype plugs in

- **Date:** 2026-11-27
- **Author:** crew: Engineer (T-0065)
- **Type:** Design record / Library behaviour / Bug root cause (P-117)
- **Related:** T-0065, P2-01, plan 02 §2.1 to §2.8, ADR-0009, ADR-0015, ADR-0016 (proposed), F-0021, P-117, tool/loc (P2-02)

## Summary
`tool/mcgen` is a **standalone pub package with its own lockfile** (like `tool/loc`), run as `fvm dart run tool/mcgen/bin/mcgen.dart`. It has **no Bazel target**. Bricks are in **mason's format but rendered with `package:mustache_template`** (mason's own engine, already in the offline cache), so mason is not a dependency. Dart output is **formatted by the pinned SDK's `dart format` in a subprocess**, not by a linked `dart_style`, because the cache has no `dart_style` 3.1.13 (the version Dart 3.13.5 bundles). **P-117's root cause** is that a nested `.dart_tool` changes two things for a standalone package's files: how `include: package:mc_analysis/...` resolves, and which language version applies. The fix is a per-package `analysis_options.yaml` that includes nothing, plus an SDK floor of `^3.13.0`. Section 5 lists the extension points P2-04 to P2-07 use.

## 1. Packaging: standalone package, isolated lockfile, no Bazel target
| Option | Verdict |
|---|---|
| Pub workspace member (`resolution: workspace`) | **No.** Every mcgen dependency would join the app's single-version resolution, which plan 02 §2.1 forbids. Adding `mustache_template` (not in the root lock) would change `pubspec.lock` and `MODULE.bazel.lock`, which the brief forbids. A later `analyzer` or `image` bump (P2-09, P2-15) would churn both locks again. |
| **Standalone package with its own `pubspec.lock`** | **Chosen.** It is the same shape as `tool/loc`. It resolved **offline** (`fvm dart pub get --offline`): args 2.7.0, crypto 3.0.8, mustache_template 2.0.5, path 1.9.1, yaml 3.1.4, test. The app's `pubspec.lock` and `MODULE.bazel.lock` are byte-identical to `origin/main` (`T-0065-AC5_gates.sh` step 5). |
| A Bazel `dart_binary` / `dart_test` on an isolated hub | **Not done.** An isolated hub is a second `pub` extension over `tool/mcgen/pubspec.lock` in `MODULE.bazel`, so `MODULE.bazel.lock` changes, which the brief forbids. Reusing `@pub_deps` is also out: `mustache_template` isn't in it, and two resolutions of one package (`yaml` from mcgen's lock in `fvm dart test`, but from the app's lock in Bazel) could drift. The tests also shell out to the pinned `dart format` and `dart analyze`, which a Bazel sandbox does not have. **Consequence:** `test //...` does not run mcgen's tests. `tool/checks/T-0065-AC5_gates.sh` runs them, and the TL runs it next to the merge gates. Revisit once a PO-approved `MODULE.bazel` change for tool hubs is acceptable. |

## 2. Renderer: mustache_template in mason's brick format, not mason
- **mason is not in the offline cache.** Fetching it would pull its dependencies (archive, http, mason_logger, pool, pub_semver, json_annotation, …) for features mcgen doesn't use: mcgen precomputes every variable, and plan 02 §2.4 says templates stay logic-less, so lambdas, partials and hooks are never needed.
- **mason renders with `package:mustache_template`.** I checked mason's `pubspec.yaml` and `lib/src/render.dart` on GitHub (2026-11-27): it depends on `mustache_template: ^2.0.0` and calls `Template(source, lenient: true, partialResolver: …)`, with default HTML escaping. Using the same engine directly gives the same output for the logic-less subset, so humans can still run `mason make <brick> -c vars.json` (mason's brick format: `brick.yaml` + `__brick__/`).
- **Escaping is the same as mason's:** `{{x}}` HTML-escapes and `{{{x}}}` is raw. **Templates write every value as `{{{x}}}`**, because a pubspec constraint such as `>=1.0.0 <2.0.0` would otherwise come out as `&gt;=`. `brick_test.dart` pins both forms.
- **mcgen is stricter than mason:**
  - `lenient: false`, so a missing value throws (`Value was missing for variable tag: x`) instead of rendering an empty string. A template that renders strictly renders the same leniently;
  - the given variables must equal `brick.yaml`'s `vars` exactly (missing or undeclared → error);
  - a path that renders empty, or with an empty segment, is skipped (mason's conditional-file idiom);
  - `..` and absolute paths are refused.
- **Standalone section tags vanish with their line** (mustache spec), so `{{#has_dependencies}}` on its own line leaves no blank line. `brick_test.dart` pins this.
- **Brick templates aren't Dart:**
  - `tool/mcgen/analysis_options.yaml` excludes `bricks/**/__brick__/**` from analysis.
  - The format gate never sees a `.dart` template, because the bricks so far have none (`utility_hello`'s only brick file is `pubspec.yaml`).
  - **When P2-04 adds a Dart template** (`{{name}}.dart`), `dart format tool` will fail to parse it. Then either name Dart templates without the `.dart` suffix (`lib/{{file}}`, where `file` is a precomputed variable ending in `.dart`) or make the gate skip `__brick__/` directories. The second is the standard mason practice, and is a one-line change to `MC_FORMAT_DIRS` handling in `format_gate.sh`.

## 3. Formatter: the pinned SDK's `dart format`, in one subprocess per gen
- `fvm dart format --version` prints **3.1.13**. The offline cache has `dart_style` 3.0.1 to 3.1.7 and 3.1.14, but **no 3.1.13**. A different patch release can format differently from `tool/checks/lib/format_gate.sh`, and then the round-trip goldens (KD1) would fail for no reason.
- So `DartFormatter` (in `lib/src/core/format.dart`):
  - writes the module's Dart files into a scratch directory;
  - runs `Platform.resolvedExecutable format --language-version=3.13 --trailing-commas=preserve --page-width=80` once over them;
  - reads them back.

  `Platform.resolvedExecutable` is the FVM pin under `fvm dart run`. The scratch directory has its own `analysis_options.yaml`, so no file above it can leak in. Nothing about the scratch path reaches the output.
- **The pin is enforced:** `mcgen.yaml` has `formatter_version: 3.1.13`, and mcgen refuses to format with any other version.
- **Cost:** about 0.3 s per gen. The 80 tests (all of AC1 to AC5) run in about 25 s.
- **Proof it matches the gate:** `test/golden/utility_hello/` is mcgen's output, committed under `tool/`, which the gate formats. The gate reports 0 changes, and `T-0065-AC5 the committed golden equals the output` pins golden = output. `T-0065-AC5 the output is formatted as the format gate formats` re-runs `dart format --set-exit-if-changed` on fresh output with the repo's settings: 0 changed.

## 4. P-117: root cause and fix
- **Repro** (before the fix): `cd tool/loc && fvm dart pub get --offline`, then `tool/checks/lib/format_gate.sh` reports `Changed tool/loc/lib/loc.dart` and `Changed tool/loc/test/loc_test.dart`. Without `tool/loc/.dart_tool`, the gate passes.
- **Cause 1, the options:** `tool/loc` has no `analysis_options.yaml`, so the formatter uses the root file. That file says `include: package:mc_analysis/analysis_options.yaml`, and the formatter resolves the include through the **nearest** package config. With a nested `.dart_tool` that is tool/loc's own config, which has no `mc_analysis`. The include fails and the formatter falls back to the default style, which drops `trailing_commas: preserve`.
- **Cause 2, the language version** (found while fixing cause 1). With a nested config, `tool/loc`'s files get **its** language version: `sdk: ^3.11.0` gives 3.11. Without one, they belong to no package in the root config and get the latest version, 3.13. The two versions format method chains differently:

  ```dart
  File(p.join(…))\n    .readAsStringSync()   // 3.11
  File(\n  p.join(…),\n).readAsStringSync()   // 3.13
  ```

  After cause 1 was fixed, the gate still failed on exactly these lines.
- **Fix, for both packages:**
  - `tool/loc/analysis_options.yaml` and `tool/mcgen/analysis_options.yaml` include nothing (`formatter: trailing_commas: preserve`, plus mcgen's strict analyzer modes);
  - both pubspecs have `sdk: ^3.13.0`. tool/loc's `pubspec.lock` was unchanged by the bump.

  The gate now gives the same answer with or without a nested `.dart_tool`. `T-0065-AC5_gates.sh` runs `pub get` in both packages first, then the gate: PASS.
- The other remedy (have the gate delete or refuse a nested `.dart_tool`) was not taken. Deleting would destroy a developer's `pub get`, and refusing would block any developer who ran tests.

## 5. Extension points for P2-04 to P2-07 (and P2-08, P2-09)
1. **An archetype** is a class extending `Archetype` (`lib/src/core/archetype.dart`), registered in `lib/src/archetypes.dart`. It provides:
   - `name` and `tiers`;
   - `lint(spec)`, which adds the archetype's own rules, including the shape of `spec.options` (the schema leaves `options` free-form);
   - `emit(EmitContext ctx)`.

   It lives in `lib/src/emit/<archetype>/`, with its bricks in `bricks/<archetype>*/`. `utility_hello` is the worked example.
2. **`EmitContext`** (`lib/src/core/emit.dart`):
   - `ctx.library(DartLibrary)` for IR files, and `ctx.file(path, text)` for plain ones;
   - `ctx.brick(name, vars)` renders a whole brick;
   - `ctx.deferred(path, (UseGraph g) => …)` builds files that need the resolved use-graph (pubspec deps now, BUILD deps in P2-08);
   - `owned: true` marks a file as written once, which counts only in `mixed` modules. Spec `owned:` globs also count.
   - `ctx.rng` is the module stream. **Always fork by concern** (`ctx.rng.fork('screens').fork(screen.name)`), never draw from the root, so a new knob reshuffles nothing.
3. **IR** (`lib/src/core/ir/`):
   - declarations: `ClassDecl`, `EnumDecl`, `ExtensionTypeDecl`, `FunctionDecl`, `RawDecl` (the escape hatch for typedefs, mixins, top-level variables);
   - members: `RawMember`, and `Method` with a `Body`;
   - `Keep(id, defaults)` is a statement, so **keep regions can only be emitted inside bodies**, as plan 02 §2.6 requires;
   - code is text with `ref('Name')` markers (NUL-delimited, so they can't collide with source).
4. **Symbols:**
   - `ctx.library` registers every named declaration under its `package:` URI (lib/ only).
   - Register a dependency's public names with `ctx.symbols.external('Money', 'package:mc_formatters/mc_formatters.dart')`.
   - An unknown or ambiguous reference is an error, never a guess; pin one with `ref(name, from: uri)`.
   - P2-04 will want a shared table of the first-party kits' exports (`McBloc`, `FeatureFlow`, the `mc_ds_*` widgets). Build it once in `lib/src/core/` (or `lib/src/emit/common/`) rather than per archetype.
5. **Imports and the use-graph:**
   - `resolveLibrary` and `renderLibrary` write exactly the imports in use (dart: first, then `package:`, then exports, then parts; each sorted by code unit).
   - `UseGraph.libDeps` and `devDeps` give the pubspec, and `UseGraph.edges` gives file → URI edges for buildgen (P2-08) and SCC metrics (P2-09).
   - `PackageCatalog.pubspecEntry` gives `any` for first-party packages, the `mcgen.yaml` constraint for third-party ones, and the `sdk: flutter` form.
6. **The round-trip golden (KD1):** `compareToExemplar(gen, exemplarDir, ignore: …)` in `lib/src/core/roundtrip.dart`.
   - It drops the mcgen header and keep-region bodies on both sides, skips `defaultExemplarIgnores` (ide_sync and `pub get` artefacts, `.mcgen/`), and returns a `TreeDiff` that gives the first differing line of each file.
   - **Exemplars have no keep markers.** P2-04 adds `// mcgen:keep <id>` … `// mcgen:end <id>` around the exemplar's hand-written bodies (exemplars are `ejected`, so nothing else changes), and then the round-trip ignores those bodies.
   - Files the archetype doesn't generate yet (`BUILD.bazel` until P2-08) go in `ignore`.
   - Use `Generator.generate` directly (see `test/cli_test.dart` `_render`), or `mcgen gen --out <dir>`, which ignores ownership, so an ejected exemplar's spec still renders.
7. **Byte-for-byte prose:** exemplars are full of hand-written comments. The spec carries `doc:` on entities, fields, endpoints, rules, blocs, flows, screens and the navigator, and `DartLibrary.preamble` takes a file's leading comment block. Fixed prose belongs in bricks.
8. **Headers:** managed Dart, YAML and `.feature` files start with `// Scaffolded by mcgen from mcgen.yaml; edit the spec or a keep region.` and one blank line. JSON and ARB files have no header. `headerFor(path)` is the single definition.
9. **The writer** (`planWrite`, then `applyPlan`) is all-or-nothing across every module of one `gen`. Drift kinds: `hand-edit`, `keep-damage`, `orphan-keep` (a dropped region still holds code), `unmanaged` (mcgen never wrote the file), `stale-manifest`. `--force` overrides them all, still carries keep bodies over where the markers are intact, and logs `(forced over …)`.

## 6. Small facts worth knowing
- **FNV-1a 64 and SplitMix64 vectors:**
  - FNV: `""` gives `0xcbf29ce484222325`, `"a"` gives `0xaf63dc4c8601ec8c`, `"foobar"` gives `0x85944171f73967e8`;
  - SplitMix64 seed 0 gives `0xe220a8397b1dcdaf, 0x6e789e6aa1b965f4, 0x06c45d188009454f` (Vigna's reference).

  `rng_test.dart` checks all of them against an independent BigInt implementation. Dart VM `int` arithmetic wraps at 64 bits, and `>>>` is the unsigned shift. mcgen never runs on the web.
- **A fork is `splitMix64Mix(parentSeed ^ fnv1a64(name))`.** It never consumes a parent draw, so the order in which forks are made doesn't matter.
- **The spec hash** is sha256 of the canonical JSON of the parsed YAML (keys sorted, no whitespace), so comments and key order in `mcgen.yaml` don't make the manifest stale.
- **The manifest hash is tool/loc's**: sha256 of the content without keep-region bodies, joined with LF. `T-0065-AC2 keep-region lines count as hand, the rest as scaffold` runs tool/loc on generated output and gets hand 1 and scaffold 18. After an edit inside the region it gets 2 and 18. After an edit outside, it gets 17 and 3.
- **`dart run` from the repo root works** when given the script path (`fvm dart run tool/mcgen/bin/mcgen.dart`), because the VM finds `tool/mcgen/.dart_tool/package_config.json` from the script. `fvm dart run tool/mcgen` (a directory) does not.
- **`tool/mcgen/test/golden/utility_hello/pubspec.yaml`** is a real pubspec with `resolution: workspace`. Nothing scans `tool/` for packages: `mc_arch_check` and `tool/loc` scan only `app/`, `feature/` and `utility/`, and the root workspace lists its members explicitly.
