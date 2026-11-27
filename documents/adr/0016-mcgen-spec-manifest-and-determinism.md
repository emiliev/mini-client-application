# ADR-0016: mcgen's contracts: the `mcgen/1` spec, the manifest, keep regions and seed derivation

- **Status:** Accepted (TL, 2026-11-27, at the T-0065 merge `a6da9bde`)
- **Date:** 2026-11-27
- **Deciders:** Tech Lead
- **Related:** T-0065, F-0065, plan 02 §2.1 to §2.6 and KD1/KD4/KD5, ADR-0009, tool/loc (P2-02), P-117

## Context
About 95 feature specs and their generated packages will be committed with these formats (S1 to S3), and S4's synthesised workspaces are reproduced from a seed. Four of mcgen's choices can't be changed later without re-touching every spec and every generated module, re-baselining every manifest and re-rolling every seeded choice:
- the spec's shape;
- the manifest format, which tool/loc already reads;
- the keep-region syntax, which hand-written code will sit inside;
- how seeds are derived.

## Options considered
### Spec: one generic schema, or a schema per archetype
- **Per-archetype schemas:** each archetype checks its own spec tightly. But shared parts (entities, endpoints, rules, BDD) would be defined seven times, and lint and the shape engine (P2-09) couldn't treat specs uniformly.
- **One schema plus an `options` object per archetype (chosen):** plan 02 §2.2's vocabulary is fixed for every archetype, and whatever is archetype-specific goes under `options`, which the archetype's `lint` validates.

### Manifest: per-module file, or one repo-wide file
- **Repo-wide:** every batch would collide on one file (plan 02 KD10).
- **Per module, at `.mcgen/manifest.json` (chosen):** this is the layout tool/loc already reads.

### Seeds: stream position, or name-derived forks
- **Stream position (one RNG drawn in order):** adding a draw anywhere reshuffles everything after it.
- **Name-derived forks (chosen):** see Decision 4.

## Decision
1. **Spec `mcgen/1`** (`tool/mcgen/schema/mcgen-1.json`, JSON Schema 2020-12 subset):
   - **Required:** `schema`, `module`, `tier` (`app|feature|utility`), `archetype` and `ownership` (`managed|mixed|ejected`).
   - **Optional:**
     - `description`, `size_class`, `seed_salt`;
     - `deps` and `dev_deps`, which list packages, never `mc_design_system`;
     - `owned` (globs; mixed only) and `keep` (declared region ids, each of which must be emitted);
     - the domain: `entities` (exactly one of `fields`, `enum` or `union`), `endpoints`, `rules` (examples required), `blocs`, `flow`, `screens`, `navigator`, `l10n`, `mixins`, `bdd` (scenario ids `MC-<module>-NN`);
     - `options`, which is archetype-specific.
   - `doc:` on named parts carries prose, so generated files can match exemplars byte for byte.
   - **Shape rules:** types are Dart type strings (`Page<Character>?`); signatures are `name(args) -> Return`; unknown keys are errors.
   - **Location:** the spec lives in its module's directory, `<tier>/.../<module>/mcgen.yaml`, and the directory name equals `module`.
   - **Compatibility:** a breaking change to the spec means `mcgen/2` and a migration, never a silent reinterpretation.
2. **The manifest** at `<module>/.mcgen/manifest.json`, schema `mcgen-manifest/1`, has these fields:
   - `archetype`, `generator` (`mcgen <version>`), `module`, `ownership`;
   - `seed` (`0x` plus 16 hex digits);
   - `spec_hash`: sha256 of the canonical JSON of the spec, so comments and key order don't count;
   - `files`: `{<module-relative path>: {hash, ownership: managed|owned, keep?: {<region id>: <sha256 of the region's default body>}}}`. The default-body hash tells a body mcgen wrote from one a human filled in: a dropped file or region whose body differs from its default is never deleted without `--force` (`orphan-keep`).

   It is written with keys sorted by code unit, a two-space indent, LF and a final newline. `hash` is **tool/loc's rule**: sha256 of the content without the lines strictly between keep markers, joined with LF. For an `owned` file, `hash` is the first-write hash.
3. **Keep regions and headers:**
   - A region is `// mcgen:keep <id>` … `// mcgen:end <id>` (`#` in YAML). Ids match `[a-z][A-Za-z0-9_.-]*`.
   - Regions appear only inside bodies, which the IR enforces.
   - A region's body is preserved verbatim; its default body is emitted only when the region is new.
   - Managed Dart, YAML and `.feature` files start with `// Scaffolded by mcgen from mcgen.yaml; edit the spec or a keep region.` (or `#`) and one blank line. JSON and ARB files have no header.
4. **Seeds:**
   - The module stream is `SplitMix64(fnv1a64("$globalSeed/$module/$seedSalt"))`, with `global_seed` set in `tool/mcgen/mcgen.yaml` (20261127).
   - `fork(name)` gives a stream seeded with `splitMix64Mix(parentSeed ^ fnv1a64(name))`, so forking never consumes a draw.
   - Every draw goes through a named fork. `dart:math` `Random` is never used.
5. **Ownership and the clobber guard:**
   - Before writing, every file's keep-stripped hash is compared with the manifest.
   - A gen with drift writes nothing, in any module of the run.
   - `--force` overrides the guard and logs what it overrode.
   - `mixed` modules write `owned` files once; `ejected` modules get nothing written.
6. **Formatting:** the pinned SDK's own `dart format` (version pinned in `mcgen.yaml`), language 3.13, `trailing_commas: preserve`, page width 80. That is exactly what the repo's format gate uses (F-0065 §3).

## Consequences
- **Positive:**
  - Regeneration is reproducible across machines and checkouts (T-0065-AC1, AC3), and hand work in keep regions and owned files survives it (AC2).
  - tool/loc's hand/scaffold split works on mcgen output with no change to loc.
  - P2-04 to P2-07 only add an `Archetype`, bricks and `options` rules.
- **Negative / trade-offs:**
  - Changing `global_seed`, the fork derivation or the hash rule re-rolls or re-baselines every module.
  - A new formatter version means regenerating everything; mcgen refuses to run under any other version.
  - Generated files differ from their exemplars by the header line, so the round-trip compares them modulo the header (and modulo keep bodies).
- **Follow-ups:**
  - P2-04 adds keep markers around each exemplar's hand-written bodies, so the round-trip can ignore them.
  - A shared table of the first-party kits' exported symbols (F-0065 §5.4).
  - If a PO-approved `MODULE.bazel` change for tool hubs becomes acceptable, a Bazel target for mcgen's tests (F-0065 §1).
