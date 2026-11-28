# tool/mcgen

The module generator (plan 02 section 2; ADR-0016; F-0065). A committed spec
per module (`<tier>/.../<module>/mcgen.yaml`, schema `schema/mcgen-1.json`)
becomes a package: fixed-shape files from mason-format bricks, variable
code from typed emitters, plus `.mcgen/manifest.json`.

```sh
(cd tool/mcgen && fvm dart pub get --offline)       # once; own lockfile, not a workspace member
fvm dart run tool/mcgen/bin/mcgen.dart spec lint --all
fvm dart run tool/mcgen/bin/mcgen.dart gen <module|path>... [--check] [--force]
fvm dart run tool/mcgen/bin/mcgen.dart gen --out <empty dir> <module|path>
fvm dart run tool/mcgen/bin/mcgen.dart check [--all | <module|path>...]
(cd tool/mcgen && fvm dart test)                    # or tool/checks/T-0065-AC5_gates.sh
```

Every command takes `--root <dir>` (default: the git root above the working
directory). Exit codes: 0 ok, 1 problems (lint errors, drift, a `--check`
diff), 3 not built yet, 64 usage. `spec synth`, `wire`, `buildgen`, `owners`,
`new`, `synth` and `stats` print `not yet (P2-xx)`.

## Layout

| Path | What |
|---|---|
| `bin/mcgen.dart`, `lib/src/cli.dart` | the command line |
| `lib/src/core/` | spec model, schema validator, lint, RNG, IR, symbol table, import resolver, use-graph, bricks, formatter, generator, writer, manifest, check, round-trip harness |
| `lib/src/emit/<archetype>/` | one typed emitter per archetype (P2-04 to P2-07) |
| `lib/src/archetypes.dart` | the archetype registry |
| `bricks/<brick>/` | mason bricks (`brick.yaml` + `__brick__/`), rendered with mustache_template |
| `schema/mcgen-1.json` | the spec schema |
| `mcgen.yaml` | global seed, the pinned formatter, third-party constraints |
| `test/golden/utility_hello/` | what the reference archetype must produce, byte for byte |
| `lib/src/emit/common/` | what every archetype shares: the kit-symbol table (checked against the kits' barrels), the shared-step table, `.feature` rendering |
| `tool/T-0069-AC3_ld_probe.sh` | generates a throwaway list-detail module into the repo, runs its analysis and tests under Bazel, deletes it |

## Archetypes

| Archetype | Exemplar (its golden) | Since |
|---|---|---|
| `list_detail` | `feature/characters/characters_list` | T-0069 (P2-04) |
| `utility_hello` | none: the reference archetype the core is tested with | T-0065 |

An **exemplar** is hand-built: its spec says `ownership: ejected` and
`exemplar: true` (ADR-0017). `gen` writes only its `.mcgen/manifest.json`;
`gen --check` and `check` render the spec and compare the render with the
module, byte for byte outside keep-region bodies and owned files' contents.
A template change that alters the exemplar fails there, naming the file and
its first differing line. See F-0069 for how the list-detail spec is laid out
and what P2-05 to P2-07 can reuse.

`utility_hello` is a reference archetype for testing the core, not an
exemplar. See F-0065 for how to add an archetype.

### Bricks
- Fixed-shape files are mason bricks (`bricks/<brick>/`). A **Dart brick**
  holds declarations only, writes references as `«Name»` (`«!Name»` for an
  extension it uses without naming), and is added with `ctx.dartBrick`; mcgen
  writes its imports (`feature_list_detail_di`).
- The format gate skips `__brick__/` directories (P-120 (a)), so a template
  may be named `.dart`. Never name one `BUILD` or `BUILD.bazel`: Bazel would
  load the brick as a package. Name it after a variable (`{{{build_file}}}`).
