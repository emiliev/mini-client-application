# ADR-0017: mcgen exemplars, the additive `mcgen/1` extensions, and the list-detail spec model

- **Status:** Proposed (crew: Engineer, T-0069)
- **Date:** 2026-11-28
- **Deciders:** Tech Lead
- **Related:** T-0069, F-0069, ADR-0016, ADR-0015, F-0065, plan 02 §2.2 to §2.6 and KD1, P2-04 to P2-07

## Context
P2-04 is the first real archetype. Its exemplar, `characters_list`, must regenerate byte for byte (KD1), and every later archetype (P2-05 to P2-07) copies the pattern. Five choices are costly to reverse, because every exemplar spec, every generated module and the next three archetypes depend on them:
1. **How an exemplar relates to its spec.** The exemplar is hand-built and has no mcgen header. Yet `mcgen gen <exemplar> --check` has to mean something, and tool/loc needs a manifest to count its scaffold lines.
2. **What the core spec lacks for a real feature.** Typed query parameters, the module's strings, and Gherkin as the exemplars write it: a Feature description, a multi-step Background, Scenario Outlines with Examples, and AC tags instead of `MC-` ids.
3. **The list-detail (LD) spec model:** which concepts the archetype knows, and how a spec states them.
4. **Which test files mcgen keeps managing,** and which become hand-owned.
5. **Where the hand-written prose of an exemplar lives.**

## Options considered
### 1. Exemplar and spec
- **A. Make the exemplar `managed`.** Every file gets the header, so the exemplar changes beyond comment markers, which the task forbids. A hand edit would also be refused as drift.
- **B. Leave it `ejected`, and compare in a test only.** `gen --check` then exits 0 on anything, so it proves nothing. And there is no manifest, so tool/loc counts the whole exemplar as hand.
- **C. `ejected` plus `exemplar: true` (chosen).** It renders without headers. `gen` writes only the manifest. `gen --check` and `check` are the round-trip, and any difference is `round-trip` drift naming the file and its first differing line. `--force` cannot override this drift.

### 2. The core spec
- **A. Put everything under `options`.** BDD, strings and query types are needed by every archetype, so each would have to reinvent them.
- **B. A new schema, `mcgen/2`.** Nothing existing breaks, so a version bump buys nothing.
- **C. Additive `mcgen/1` keys (chosen).** Every spec valid before stays valid and means the same.

### 3. The LD model
- **A. Free-form widget trees per screen** (plan 02's `screens: {layout, depth, widgets}`). This is what P2-09 needs for size realism, but no exemplar can be reproduced from it.
- **B. Concepts (chosen):**
  - a **list** of one entity from one paged endpoint, with **filters** (flow arguments that narrow the query);
  - a **preview** of the tapped item, with **actions**, each leaving the feature through one navigator method with the item's id;
  - **sections**: related items from their own endpoint, each item leaving the same way;
  - **mappers** from DTOs to domain models.

  The class names, keys, l10n keys and test-env helper names all follow from the module name and three nouns (`item`, `items`, `list_noun`). Size-driven widget variation (P2-09) can later be added inside these pages without changing the model.

### 4. Test-file ownership
- **A. Manage every test file.** The env's fixture lookups (`CharacterUniverse(42, …).byName`) and the contract test's fixture facts are top-level declarations. ADR-0016 lets keep regions sit only inside bodies, so those can't be kept. That leaves code in YAML, counted as scaffold.
- **B. Own every test file** after its first write (plan 02 §2.3 says so for steps). Then the round-trip checks none of the step templates.
- **C. Split them (chosen):**
  - `.feature` files, the step files mcgen has a template for, the flow-scope test and the architecture test are **managed**;
  - the test env (`test/feature/util/<module>_env.dart`) and the contract test are **owned**, so mcgen writes them once from a template plus the spec's `tests.env` expressions;
  - a step no template knows becomes an **owned, failing stub**.

### 5. Prose
- **A. Keep regions around comments.** These add noise to the exemplar. And since comments are not LOC, they would only hide template text from the round-trip.
- **B. Carry it in the spec (chosen):**
  - `doc:` where the core has it;
  - `options.prose: {<slot>: text}` for every other doc comment, preamble, test name or comment the templates write.

  Each slot has a default written from the nouns. An exemplar overrides only the slots whose text is its own, such as task ids and history.

## Decision
1. **Exemplars.** The new top-level key is `exemplar: true` (lint: `ownership: ejected`).
   - An exemplar renders without the mcgen header, and its manifest hashes that form.
   - `gen` writes only `.mcgen/manifest.json`, and only when the round-trip is clean.
   - `gen --check` and `check` report every difference as `round-trip` drift. That covers a file rendered but missing, a file present but not rendered, and a differing line.
   - `owned:` is allowed in an exemplar. An owned file the archetype emits must exist, but its content is not compared. An exemplar file matching an owned glob that the archetype does not emit (a legacy golden) is not expected.
   - `mcgen.yaml` itself is never compared.
2. **Additive `mcgen/1`:**
   - `endpoints[].query[]` is a name or `{name, type, default, required, doc}`.
   - `l10n.strings[]` is `{key, description, text: {<locale>: string}}`, in ARB order. A missing `en_XA` gets a pseudo-translation.
   - `bdd[]` gains `title` and `description`. `background` is a step or a list of steps.
   - `scenarios[]`:
     - gain `examples` (a table, header first), which makes the scenario an Outline;
     - their `id` becomes optional, but lint requires it outside exemplars;
     - a present id is rendered as the first tag.
3. **The LD model:** the `options` keys are `item`, `items`, `list_noun`, `ids`, `list`, `mappers`, `preview`, `tests` and `prose`.
   - Unknown keys are lint errors. So are references to missing entities, fields, endpoints, query parameters, navigator methods and strings.
   - The test env's names follow the same conventions. A managed step references `charactersScrollable`, `characterNamed` and the rest, and the owned env provides them.
4. **Keep regions** sit where LD features differ most:
   - each preview action's handler: `preview.<event>`;
   - each section item's tap: `section.<Section>.open`.

   Their default is the navigator call.
5. **Test symbol scoping** (core): a test file's declarations register under a `path:` URI.
   - Only other test files resolve them, as relative imports.
   - A test file prefers its module's own declarations, because the env re-declares `lib/src` keys.
   - A `lib/` file never sees them.

## Consequences
- **Positive:**
  - `characters_list` round-trips: 51 files compared byte for byte, and 2 owned files checked to exist. A one-field spec change fails `--check` and names the file (T-0069-AC1).
  - A second LD module with other names, no filter and no section generates, analyses clean and passes 7 BDD scenarios under Bazel (T-0069-AC3).
  - P2-05 to P2-07 reuse several parts:
    - exemplar mode;
    - the BDD rendering and the shared-step table;
    - the kit-symbol table;
    - Dart bricks, part files and the test-file imports;
    - the prose slots;
    - the BUILD and pubspec dependency rules.
- **Negative / trade-offs:**
  - An exemplar spec is long, about 420 lines for `characters_list`, mostly prose. Prose slot ids become an interface between templates and specs: renaming a slot silently falls back to the default, and the round-trip then fails, which is how it is caught.
  - The LD model covers what `characters_list` and the probe exercise. A second filter type, path parameters or non-GET endpoints are lint errors until a module needs them.
  - Owned test files are hand-written. tool/loc counts them as hand (275 of 717 test lines in `characters_list`).
  - `dart format` puts a keep region's end marker at the `case` indent when the region ends a switch case (F-0069).
- **Follow-ups:**
  - P2-08 (`mcgen wire`/`buildgen`) should take over `flow_scope.dart`'s root-import list and the BUILD rules that `package.dart` holds now.
  - P2-09 should add size-driven widget variation inside the LD pages.
