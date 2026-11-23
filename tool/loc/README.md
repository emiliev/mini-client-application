# tool/loc

The D8 / R1 LOC counter (plan 02 section 4). Output schema `mc-loc/1`.

```sh
fvm dart run tool/loc/bin/loc.dart <root> [--json out] [--md out] [--strict] \
    [--generated-root dir] [--include-untracked] [--stamp s] [--commit sha]
cd tool/loc && fvm dart test        # tests; fixtures resolve independent of cwd
```

`dart test tool/loc` from the repo root needs a root `pubspec.yaml` (none yet).

## Counting

A line counts iff a non-comment token covers it and it has a non-whitespace
character (analyzer scanner, `precedingComments` skipped).

## Which files

Files come from `git ls-files` (tracked only). `--include-untracked` adds
untracked, non-ignored files. Outside a git work tree the tree is walked and a
warning is emitted.

Dropped input is never silent: `.dart` files under `app/`, `feature/`,
`utility/` with no module `pubspec.yaml` go to a synthetic `(unowned:<tier>)`
module, and warnings appear in the JSON (`warnings`), the Markdown and stderr.
Under `--strict` these fail the run: committed generated files (not in
`tool/build_runner_overlay/fallback.yaml`), unowned files, unparseable
`pubspec.yaml`, malformed `.arb`, malformed `.mcgen/manifest.json`.

## Generated code

- Suffixes `.g.dart`, `.freezed.dart`, `.config.dart`, `.gr.dart`.
- l10n: only in a module with `l10n.yaml`, within its `output-dir` (else
  `arb-dir`, else `lib/l10n`), named `<output-localization-file stem>[_<locale>].dart`.
- BDD: `<stem>_test.dart` with a sibling `<stem>.feature`.
- A combined `.g.dart` is split by source_gen section header
  (`// ***`, `// RetrofitGenerator`, `// ***`); lines before the first header
  join the first section; no header means `json`.
- `--generated-root` counts only files of a generator kind under a first-party
  tier path (`app/`, `feature/`, `utility/`), so `external/` and source copies
  are excluded.

## `.mcgen/manifest.json`

Per module, at `<module>/.mcgen/manifest.json`:

```json
{
  "archetype": "list_detail",
  "files": {
    "lib/src/domain/model/item.dart": {"hash": "<sha256 hex>", "ownership": "managed"}
  }
}
```

Keys are paths relative to the module. `ownership` is `managed`, `owned` or
`ejected`. `hash` is the sha256 of the file content with the bodies of keep
regions removed (lines strictly between `// mcgen:keep <id>` and
`// mcgen:end <id>`). A listed, non-ejected file whose hash matches is
`scaffold`; keep-region lines, drifted, ejected and unlisted files are `hand`.
Without a manifest everything is `hand`.

## Mixins

`mixins.authored` / `generated` count `MixinDeclaration` nodes (`mixin class` is
a class). `mixins.with_applications` counts mixin types in `with` clauses of
authored source.
