# T-0069: `mcgen` list-detail archetype: regenerate `characters_list` byte for byte (P2-04)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (**Opus**: the first real archetype; it sets the pattern for P2-05 to P2-07) |
| Verification | ADR-0015: `/code-review`, one fix round, TL merge gates |
| Branch | `fleet/T-0069-mcgen-list-detail` |
| Created | 2026-11-28 |
| Depends on | T-0065 (`mcgen` core, ADR-0016), T-0032/T-0034 (the `characters_list` exemplar) |
| Related | plan 02 §2.2–§2.7, P2-04 (AC1: "Given the archetype's exemplar and its spec, when `mcgen gen` runs, then the output equals the exemplar except keep-region contents"), P1-24 (bricks); F-0065 §5 (extension points); P-120 (a), (b) and (d); ADR-0015 (no feature goldens; generated features follow it) |

## Goal
This is the first real template. Define the **list-detail (LD) archetype** in `mcgen`: bricks for the fixed-shape files and typed emitters for the variable ones. Then write `feature/characters/characters_list/mcgen.yaml`. Running `mcgen gen characters_list` must reproduce the merged exemplar **byte for byte**, except the contents of keep regions. Once that holds, any new LD feature is a spec plus generation.

## Scope
- **In:**
  - **Prerequisites from P-120:**
    - **(a)** The format gate must not break on brick templates. Skip `__brick__/` in `tool/checks/lib/format_gate.sh`, or name templates so they aren't `.dart`; pick one and document it.
    - **(b)** A shared table of the first-party kits' exported symbols (`McBloc`, `FeatureFlow`, `McFlowBackButton`, `Result`, `ApiFailure`, …), generated from or checked against the kits' barrels, so archetypes don't register them by hand.
    - **(d)** Spec lint rejects module names that gen-l10n misparses (for example a trailing `_in`, F-0066).
  - **`tool/mcgen/lib/src/emit/feature_list_detail/` and `tool/mcgen/bricks/feature_*`.** These cover every file of `characters_list`:
    - pubspec, BUILD, barrel;
    - DI (`di_initializer.dart`, `flow_scope.dart`);
    - domain models (freezed/json), API (retrofit), repository;
    - flow and flow state, navigator;
    - blocs and states, pages and widgets;
    - l10n ARBs (en, de, en_XA);
    - BDD `.feature` files and steps, contract tests, and any other tests in the package.
  - **Hand-written logic** that templates can't express goes inside **keep regions**. Add `// mcgen:keep <id>` … `// mcgen:end <id>` markers to the exemplar's hand-written bodies. These are comment-only edits to `characters_list`; its behaviour and tests must not change. Keep the keep regions few and small, and report the hand share (`tool/loc` on the manifest).
  - **The exemplar's existing goldens:** decide whether `mcgen` emits them, or the spec lists them as `owned:` files. ADR-0015 says no new feature goldens, so the archetype must not emit goldens for new features.
  - **The round-trip golden** is a `tool/mcgen` test that uses `compareToExemplar` against the real `feature/characters/characters_list`.
  - **Second LD module, the proof that it generalises:** a spec for a small **throwaway** LD module, such as `zz_ld_probe` in a temp dir, with different entities and endpoints. It must generate, pass `dart analyze` with `mc_analysis`, and pass its template BDD test under Bazel. Don't commit the module, only the test that generates and checks it.
- **Out:**
  - the other archetypes (P2-05 to P2-07);
  - `mcgen wire`/`buildgen` (P2-08): routes and wiring files stay hand-written for now;
  - spec synthesis.

## Acceptance criteria
- **T-0069-AC1 (P2-04 AC1):** `mcgen gen characters_list --check` exits 0 against the merged exemplar. A test proves that changing one spec field, such as an entity field or an ARB string, makes `--check` exit 1 and names the file.
- **T-0069-AC2:** the exemplar is unchanged in behaviour after the keep markers are added:
  - `bazel test //feature/characters/characters_list/...` and the app tests are green;
  - `git diff` of `characters_list` shows only marker lines and the new `mcgen.yaml` and `.mcgen/manifest.json`.
- **T-0069-AC3:** the throwaway LD module generates, analyses clean, and passes its BDD test under Bazel, inside an mcgen test or a script.
- **T-0069-AC4:** P-120 (a), (b) and (d) each have a test or check.
- **T-0069-AC5 (gates):**
  - `test --lockfile_mode=error //...`, lint, `mc_arch_check`, the format gate, `T-0065-AC5_gates.sh` (mcgen tests) and `tool/ci/ci.sh --only` for the mcgen gate.
  - The app's lockfiles are unchanged.
  - Every cited test exists.
  - Write a finding, `F-0069-mcgen-list-detail.md`, covering the hand share, keep regions that had to exist, and template pitfalls.

## Log
- 2026-11-28: Created and dispatched (TL), as the second hybrid wave.
