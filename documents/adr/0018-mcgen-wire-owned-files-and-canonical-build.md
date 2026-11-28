# ADR-0018: mcgen's wire-owned files and the canonical BUILD form

- **Status:** Accepted (TL, 2026-11-28, at the T-0074 merge `f7230291`)
- **Date:** 2026-11-28
- **Deciders:** Tech Lead
- **Related:** T-0074, F-0074, ADR-0016, ADR-0017, plan 02 §2.8 and §7.1, plan 01 §3.4, §4.2 and §4.5, P-126, F-0049, F-0066

## Context
Phase E batches (plan 02 §7.1) must never hand-edit shared glue. After every merge the TL runs `mcgen wire && mcgen buildgen`, and a conflict in a wire-owned file or a BUILD file is resolved by regenerating it. Two choices are costly to reverse, because every generated module, every hand-written exemplar and every batch merge depends on them:

1. **Which files wire owns, and where they sit.** Today the glue is hand-written: 7 wiring groups, the app's wiring list inside `mini_client_app.dart` and `app_router.dart`, each feature's `flow_scope.dart`, and the root workspace members. Batch tasks will add about 95 modules into those groups.
2. **The form of a BUILD file buildgen writes.** The 11 feature BUILD files are hand-written in one shape, with per-package differences. Some deps are explained by no import, two legacy goldens are `size = "medium"`, and trivia_quiz has its own engine lane. buildgen must agree with all of them byte for byte (T-0074-AC1) and still derive a new module's BUILD file from its files alone.

## Options considered
### BUILD files: pure template, sidecar config, or merge
- **A. A pure function of the package (a template).** Every hand-written difference would have to become a rule or a graph change. The import graph does not explain everything that is in the lists (F-0074 §2), so this would remove edges in all 11 packages.
- **B. A sidecar file per package** (`build.yaml` with extras and overrides). It is one more file per module, and it splits a target's truth between two files. A reviewer reading the BUILD file cannot see why an item is there.
- **C. Merge with the file on disk, keeping only what a human owns (chosen).** This is Gazelle's model: `# keep` on an item, plus comments as prose. Everything else is derived and checked.

### Hand-only targets: per-statement `# keep`, or one region
- **Per-statement `# keep`.** The kept statement stays where it is, so buildgen would have to keep foreign statements in its own order.
- **One hand region at the end (chosen).** It reuses ADR-0016's marker syntax, and its statements replace the generated ones of the same key. Starlark allows this, because a rule refers to another by label, not by symbol.

### Wire layout: edit the hand-written groups, or generate whole groups
- **Have wire rewrite the 7 hand-written groups' route libraries and targets.** Their features are exemplars without route specs. They carry prose, typed parameters, nested routes and navigator logic. Rewriting them byte for byte needs a `route:` spec section for every exemplar first.
- **Generate a whole group package for each domain of the generated flows, and leave the hand-written groups as they are (chosen for now).** The app's lists, which every group feeds, are wire-owned.

## Decision
1. **Archetypes emit no `BUILD.bazel` and no `lib/src/di/flow_scope.dart`.** After `gen`, run `mcgen wire` and then `mcgen buildgen`. The round-trip ignores both files (P-126).
2. **buildgen's canonical form** (`tool/mcgen/lib/src/buildgen/`):
   - **What is derived:**
     - every statement, in buildgen's order;
     - each target's lists, from what the target's files import;
     - the runtimes that generated code uses without an import in the source (`get_it`, `json_annotation`, `flutter_localizations`, `intl`).
   - **Lists** are sorted. A package's own labels come first, then the rest by code unit.
   - **Carried over from the file on disk:**
     - the comment block above each statement (prose), matched by key: `load:<file>`, `package`, `var:<NAME>`, `rule:<name>`;
     - a statement's own text, inner comments included, when its code tokens equal the generated statement's;
     - list items marked `# keep` on their line;
     - the names of freezed targets and test targets, matched by their source;
     - the hand region `# mcgen:keep build` … `# mcgen:end build`. It must end the file and be the only region. Its statements replace the generated statements of the same key, and a test whose `main` it defines is its own.
   - `--check` compares byte for byte. Anything else that differs is regenerated.
   - `--adopt` brings a hand-written file into this form. It adds `# keep` where the imports do not explain an item, and moves verbatim into the hand region every statement that differs other than by list order. It never changes what the file builds, which `tool/mcgen/tool/T-0074-AC1_graph.sh` proves (F-0074 §3).
3. **Wire-owned files** (`tool/mcgen/lib/src/wire/`):
   - **Every feature's `flow_scope.dart`.** Its list is derived from the source (R17): the parameter types of injectable constructors, module members and `context.di<T>()` reads, minus what the package registers and what the flow provides. The doc comment above the list is the package's own.
   - **The root `pubspec.yaml`'s workspace members** under `app/`, `feature/` and `utility/`, sorted. The other members are kept.
   - **The app's lists:**
     - `app/mini_client/lib/src/wirings.dart`: `wiringInitializers`, `wiringRoutes` and `catalogueEntries`;
     - the app pubspec's `*_wiring` entries;
     - `app/mini_client/wirings.bzl` (`WIRINGS`).

     The group order comes from `tool/mcgen/mcgen.yaml` `wire.groups`.
   - **One generated group per domain of the feature specs wire routes** (`wire.domains` maps a domain to a group).
     - **Which specs:** every feature spec except an exemplar (whose glue is hand-written). That includes an ejected module while its package exists: ejecting stops gen writing the module, not its route.
     - **Which archetypes:** `list_detail` (the navigator only), `search` (an optional `?q=`, passed as `initialQuery`) and `section_detail` (`/:id`, passed as the flow's typed id; the catalogue opens the first id the spec's scenarios open).
     - **Any other archetype, a spec without a navigator, a flow of a hand-written group, or an ejected spec without a package** is a warning. It is left unwired and listed in the catalogue with the reason, so CI stays green when a new archetype produces managed modules.
     - It lives at `app/wiring/<group>_wiring/` and is marked by `.mcgen/wire.json`. The marker lists the managed files and the first-write hash of each owned one.
     - **What wire stops generating is deleted:** a managed file always; an owned file (a navigator) only while it is as wire wrote it. An edited orphan stops the run, which writes nothing and names the file, until `--force`. `--check` reports every deletion. A group with no flow left goes entirely, and leaves the app's lists.
     - It has a pubspec, a barrel, one typed route library, the route targets and their implementation, two DI initializers, a `routes_test.dart` drift test and its BUILD file.
     - Each route is absolute at `/<module-with-dashes>`, named after the module. The app nests it under home (F-0049), and the sign-in guard applies to it as to any route (F-0066).
     - The navigator implementations (`lib/src/navigators/<module>_navigator_impl.dart`) are written once and then are the engineer's.
   - **`app_core`'s `GeneratedLocations`:** one location per generated flow. `AppLocations` stays hand-written.
   - **`/catalogue`** (debug and profile builds only, with no link from home) lists `catalogueEntries`. `//app/mini_client:catalogue_test` opens each wired entry and checks that each unwired one shows its reason and does not open.
4. **Not wire-owned until their features have specs:** the 7 hand-written groups, `AppLocations`, the sandbox's router, and the app's and app_core's BUILD files beyond `WIRINGS`. A generated flow whose domain maps to a hand-written group is left unwired with a warning (F-0074 §4).

## Consequences
- **Positive:**
  - `buildgen --check` agrees with all 11 feature BUILD files. The adoption left `deps(//...)`, its 29,921 edges and every target's attributes identical.
  - `wire --check` agrees with all 11 flow scopes (derived, where they used to be hand-maintained), the workspace members and the app's lists.
  - A new list-detail spec reaches the app through `gen`, `wire` and `buildgen` alone: it builds with `--config=sim`, `test //...` passes, and it opens from `/catalogue` (T-0074-AC3).
  - Merge conflicts in these files are regenerated, not resolved.
- **Negative / trade-offs:**
  - Prose and `# keep` items are not checked: a stale comment or an unneeded kept dep survives. The 11 adopted files hold 75 kept items. Three files have hand regions (trivia_quiz, library_reading_list_editor and store_home): 113 of their 3,865 lines (2.9 %).
  - Tokens are compared, not semantics. A reordered list is a difference, and buildgen rewrites it sorted.
  - The flow-scope derivation reads the source text, not an analyzer. A constructor shape the regular expressions miss fails loudly ("cannot tell which import declares T"), but a missed parameter would not. `test/flow_scope_test.dart` in each feature still resolves every registration at test time.
  - Generated groups are per domain. Generated flows in the domains of the 7 hand-written groups need those groups' glue generated first.
- **Follow-ups** (for the TL to file):
  - a `route:` spec section and exemplar specs, so that wire can own the hand-written groups (F-0074 §4);
  - buildgen for utility packages once an archetype covers one;
  - shrinking the kept items as packages are next touched (F-0074 §2);
  - The SC and SR archetypes (T-0072, T-0073, merged during T-0074) now leave the flow scope to wire, and SC its BUILD file to buildgen. What remains of Decision 1: SC's brick still renders a BUILD file that is dropped, and the SR skeleton writes an owned first BUILD file (F-0074 §6).
