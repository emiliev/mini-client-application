# U-D-injectable (plan U-D2): rules_dart, "ext: injectable two-stage support"

| | |
|---|---|
| Target | https://github.com/Mivr/ai_rules_dart (pull request against `main`, based on v0.28.3 `e7163aa`) |
| Patch | `third_party/rules_patches/ai_rules_dart/0002-ext-injectable-two-stage.patch` (one commit; `git am` applies it on the pin) |
| Task | T-0028; finding F-0028 |
| Status | Draft, not sent (Q-013: GitHub access for upstream) |

## PR title
ext: injectable two-stage support (vendored injectable_generator 3.1.3 without lean_builder)

## PR body

injectable is one of the most used Flutter code generators, and it isn't supported by
`dart/ext` today: it is an aggregate builder, and its generator can't join the ext lock.
This adds `//dart/ext/injectable`.

**How it maps onto rules_dart**

- Stage 1, `:shim_json`: one `dart_codegen` per annotated library writes
  `<file>.injectable.json` (injectable's `injectableBuilder`, `build_to: cache` under
  build_runner).
- Stage 2, `:shim_config`: one `dart_aggregate_codegen` over the `@InjectableInit` file, with
  the shards as `asset_deps`; the generator finds them with `findAssets(Glob('lib/**.injectable.json'))`
  and writes `<init>.config.dart`.
- `defs.bzl`: `injectable_shards`, `injectable_config`, `injectable_package`.

**Three things the stock shim gets wrong for this generator, handled in `lib/injectable_shims.dart`**

1. A library with no injectable class returns `null`, and the shim writes the declared
   output empty. The config stage's `jsonDecode` throws on an empty shard. `shim_json` writes
   `[]` instead (equivalent to build_runner's missing shard).
2. When nothing is generated for the init file, the shim writes an empty `.config.dart`, and
   the failure shows up later as an undefined `init` extension. `shim_config` fails the action,
   naming the file, and rejects a shard that is not a JSON list.
3. `Resolver.libraries` order. injectable uses the first library exporting a type as its
   import and hashes the rest into the registration order. The shim's order (staged files,
   then each package's `lib/<name>.dart`) made a package barrel the import of every
   in-package type and reordered registrations that take a third-party type. Both shims wrap
   the resolver with build_runner 2.16's walk (breadth-first over imports, then exports, SDK
   libraries first). See "Follow-up issue" for the general fix.

**Why the generator is vendored**

injectable_generator 3.1.3 depends on `lean_builder ^1.2.2`, and lean_builder 1.2.2 requires
`_fe_analyzer_shared >=98.0.0 <106.0.0`; the ext lock's analyzer 14.5.0 needs `^109.0.0`.
The build_runner path (`lib/builder.dart`) imports only `build` and `source_gen`; lean_builder
is used only under `lib/lean_builder/`. The vendored copy is the pub.dev archive (sha256
`24d525c6…049df`, upstream commit `0644204`) without that directory and with the dependency
commented out; no `.dart` file is modified (`third_party/injectable_generator/VENDORED.md`,
MIT `LICENSE` kept). It goes away once injectable splits lean_builder out or lean_builder
widens its bound (issues filed, see U-X-injectable-lean_builder). The ext lock gains only
`injectable 3.0.0`.

**Evidence** (consumer repo, Bazel 9.3.0, Flutter 3.47.7 / Dart 3.13.5)

- Byte-identical to build_runner 2.16.1 + stock injectable_generator 3.1.3 (with
  lean_builder) on a sample with 5 annotated classes (lazy singleton `as:`, factory,
  singleton with `@disposeMethod`, `@factoryParam`, a `@module` with a `@Named` getter, a
  `@preResolve` async method and a third-party `Dio`): `.config.dart` and all non-empty shards.
- Early cutoff: a method-body edit re-runs the shard actions (byte-identical outputs) and
  the aggregate action is an action-cache hit (no spawn in the execution log).
- Unit tests: `//dart/ext/injectable:injectable_shims_test`.

**Not in this PR (happy to add if wanted)**

- An `e2e/ext_exemplar/injectable/` exemplar. The consumer sample can be ported as is.
- Gazelle: annotation scan entries (`@injectable`, `@singleton`, `@lazySingleton`,
  `@module`, `@InjectableInit`) and the two-stage synthesis.
- Micro-packages (`.module.dart`): the shim supports declaring the second output, untested.

## Follow-up issue (rules_dart): the shim's `Resolver.libraries` differs from build_runner's

> `builder_shim.dart` `_ShimAnalyzerResolver.libraries` yields the staged same-package files
> (in staging-completion order, which `Future.wait` doesn't fix) and then `lib/<name>.dart`
> of every package in the package config. build_runner yields the SDK libraries and then a
> breadth-first walk from the build step's entry points over imports and exports
> (`build_runner/lib/src/build/resolver/build_step_resolver.dart`). Generators that pick an
> import from `libraries` (injectable, stacked_generator's ImportResolver) produce different
> imports, and injectable a different registration order. Proposal: implement build_runner's
> walk in the shim (the injectable shim's `BuildRunnerLibrariesResolver` is a drop-in), and
> make the staged-file iteration order deterministic.
