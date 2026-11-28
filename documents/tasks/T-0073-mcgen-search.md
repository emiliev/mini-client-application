# T-0073: `mcgen` search (SR) archetype: `discovery_search` and `characters_search` regenerate byte for byte

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree). It follows the T-0069 pattern. |
| Verification | ADR-0015: `/code-review`, one fix round, then the TL merge gates |
| Branch | `fleet/T-0073-mcgen-search` |
| Created | 2026-11-28 |
| Depends on | T-0065, T-0069 (ADR-0017, `emit/common`), T-0046 (`discovery_search`, the SR exemplar), T-0071 (`characters_search`, a second SR module) |
| Related | plan 02 §2.3–§2.7, P2-05 to P2-07; F-0069; F-0046 and F-0071 (debounce, history, generation guard, paging per search) |

## Goal
Add the SR archetype to `mcgen`. The exemplar `discovery_search` (grouped results, no paging) and the hand-built `characters_search` (one domain, facets, paging) must **both** round-trip. That makes the template express both shapes.

## Scope
- **In:**
  - `tool/mcgen/lib/src/emit/feature_search/` and `tool/mcgen/bricks/feature_search_*`, plus specs for both modules (`exemplar: true`) and keep markers. Keep the markers comment-only and small.
  - The template must cover:
    - `DebouncedQuery` and `SearchHistory`, each with its own storage key;
    - the generation guard;
    - facets (sort and filter chips);
    - one paging controller per search, with the result list keyed by query and facets;
    - grouped results;
    - the minimum query length (2 in discovery, 1 in characters);
    - every state: idle, searching, results, empty, failure.
  - Reuse `emit/common`. Additions there must be additive and must not change the `list_detail` output.
- **Parallel work:** T-0072 (SC archetype) and T-0074 (wire/buildgen) are running. Own `emit/feature_search/` and `bricks/feature_search_*`. Additions to `emit/common` and `archetypes.dart` must be small and additive.
- **Out:** behaviour changes to either feature.

## Acceptance criteria
- **T-0073-AC1:**
  - `mcgen gen discovery_search --check` and `mcgen gen characters_search --check` both exit 0.
  - Changing a spec field makes `--check` exit 1 and name the file.
- **T-0073-AC2:** both features behave exactly as before. Their Bazel tests and the app tests are green. Their diffs contain only markers, `mcgen.yaml` and the manifest.
- **T-0073-AC3:** a throwaway SR module, with paging and one facet, generates, analyses clean and passes its BDD under Bazel, using a probe script.
- **T-0073-AC4:**
  - Gates: `test --lockfile_mode=error //...`, lint, the format gate, `T-0065-AC5_gates.sh`, and `characters_list --check` still up to date.
  - The lockfiles are unchanged.
  - Every cited test exists.
  - A short finding.

## Log
- 2026-11-28: Created and dispatched (TL), as part of the third wave.
