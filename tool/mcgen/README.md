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
fvm dart run tool/mcgen/bin/mcgen.dart wire [--check] [<package dir>...]
fvm dart run tool/mcgen/bin/mcgen.dart buildgen [--check] [--adopt] [<package dir>...]
(cd tool/mcgen && fvm dart test)                    # or tool/checks/T-0065-AC5_gates.sh
```

Every command takes `--root <dir>` (default: the git root above the working
directory). Exit codes: 0 ok, 1 problems (lint errors, drift, a `--check`
diff), 3 not built yet, 64 usage. `spec synth`, `owners`, `new`, `synth` and
`stats` print `not yet (P2-xx)`.

After `gen` of a new module, run `wire` and then `buildgen` (T-0074): the
module's root-import list and BUILD.bazel are theirs, not the archetype's. A
merge conflict in a wire-owned file or a BUILD.bazel is resolved by running
`mcgen wire && mcgen buildgen` again, never by hand (plan 02 section 2.8).

### wire (T-0074; F-0074)
Writes, from every spec and package:
- each feature's `lib/src/di/flow_scope.dart` (R17): the parameter types of its
  injectable constructors, module members and `context.di<T>()` reads, minus
  what it registers and what its flow provides. The doc comment above the
  list is yours and is carried over;
- the root pubspec's `workspace:` members under `app/`, `feature/` and
  `utility/`;
- the app's wiring list (`app/mini_client/lib/src/wirings.dart`: DI
  initializers, routes, `catalogueEntries`), its `*_wiring` pubspec deps and
  `app/mini_client/wirings.bzl`;
- one **generated wiring group** per domain of the feature specs it routes
  (`list_detail`, `search`, `section_detail`; every spec but an exemplar,
  ejected ones while their package exists), at `app/wiring/<group>_wiring/`,
  and `app_core`'s `GeneratedLocations`. Its navigator implementations are
  written once and are then yours. Any other flow (another archetype, a
  hand-written group's domain) is a warning, listed in the catalogue as not
  wired (F-0074 section 4);
- deletions: `.mcgen/wire.json` records what wire wrote in a group, and what
  it no longer generates is deleted (`--check` reports it). An owned file
  someone edited stops the run until `--force`.

With package directories, `wire` writes only their flow scopes (a module
generated outside the app, as `tool/T-0069-AC3_ld_probe.sh` does).

### buildgen (T-0074; ADR-0018)
Writes the BUILD.bazel of every feature package and every generated wiring
group from the package's files: its imports, parts, annotations, tests and
l10n.yaml. From the file on disk it keeps only what a human owns: the
comments above each statement, a statement's own comments when its code is
unchanged, list items marked `# keep`, and the hand region at the end
(`# mcgen:keep build` ... `# mcgen:end build`), whose statements replace the
generated ones of the same key. `--adopt` brings a hand-written file into
that form without changing what it builds (`tool/T-0074-AC1_graph.sh`
compares `bazel query` before and after).

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
| `lib/src/buildgen/` | `mcgen buildgen`: the Starlark reader, the merge, `--adopt`, the feature and wiring-group BUILD files |
| `lib/src/wire/` | `mcgen wire`: flow scopes, wiring groups, the app's lists |
| `tool/T-0069-AC3_ld_probe.sh` | generates a throwaway list-detail module into the repo, runs its analysis and tests under Bazel, deletes it |
| `tool/T-0074-AC1_graph.sh` | the Bazel graph (`deps(//...)`, its edges, every target's attributes) for a before/after comparison |
| `tool/T-0074-AC3_wire_probe.sh` | in a temp copy: a new list-detail spec, `gen`, `wire`, `buildgen`, the sim app build and `test //...` |

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
  load the brick as a package. BUILD files are `mcgen buildgen`'s anyway
  (T-0074): an archetype emits none.
