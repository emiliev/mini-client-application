# T-0072: `mcgen` section-detail (SC) archetype: `comics_details` and `characters_details` regenerate byte for byte

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree). The pattern exists now (T-0069), so this task follows it rather than designing anew. |
| Verification | ADR-0015: `/code-review`, one fix round, TL merge gates |
| Branch | `fleet/T-0072-mcgen-section-detail` |
| Created | 2026-11-28 |
| Depends on | T-0065 (core), T-0069 (list-detail archetype, ADR-0017, `emit/common`), T-0041 (`comics_details`, the SC exemplar), T-0067 (`characters_details`, a second SC module) |
| Related | plan 02 §2.3–§2.7, P2-05 to P2-07 (templatise the remaining archetypes); F-0069 (the pattern and its pitfalls) |

## Goal
Add the SC archetype to `mcgen`. **Two real modules** must round-trip, the exemplar `comics_details` and the hand-built `characters_details`, which proves that the template generalises.

## Scope
- **In:**
  - `tool/mcgen/lib/src/emit/feature_section_detail/` and `tool/mcgen/bricks/feature_section_detail_*`.
  - Specs (`mcgen.yaml`) for both modules, with `exemplar: true`.
  - Keep-region markers: comment-only, few and small.
  - Reuse `emit/common` and the list-detail pieces wherever they fit. Put anything shared into `emit/common` additively. Don't change list-detail's output: `characters_list --check` must stay green.
  - The SC parts the template must express:
    - the favourite toggle, which signs in when needed and pins writes with `authPinned`;
    - the stale-read counter and the busy-announcement flag (T-0067);
    - section blocs;
    - outbound navigator methods.
- **Parallel work:** T-0073 (the SR archetype) and T-0074 (`mcgen wire`/`buildgen`) are running at the same time.
  - Own only `emit/feature_section_detail/` and `bricks/feature_section_detail_*`.
  - Additions to `emit/common` and `archetypes.dart` are allowed. Keep them additive and small. The TL resolves any registry-line conflict.
- **Out:** any behaviour change to either feature.

## Acceptance criteria
- **T-0072-AC1:** `mcgen gen comics_details --check` and `mcgen gen characters_details --check` both exit 0 on the merged modules. Changing one spec field makes `--check` exit 1 and name the file.
- **T-0072-AC2:** both features behave exactly as before. Their Bazel tests and the app tests are green, and their diffs are only keep markers, `mcgen.yaml` and the manifest.
- **T-0072-AC3:** a throwaway SC module (in a temp dir, not committed) generates, analyses clean, and passes its BDD tests under Bazel, using a probe script like T-0069's.
- **T-0072-AC4:**
  - Gates: `test --lockfile_mode=error //...`, lint, the format gate, and `T-0065-AC5_gates.sh`.
  - `characters_list --check` is still up to date.
  - The lockfiles are unchanged.
  - Every cited test exists.
  - A short finding records the hand share and the keep regions.

## Log
- 2026-11-28: Created and dispatched (TL), as part of the third wave.
