# T-0076: `mcgen` dashboard (DB) archetype: `store_home` regenerates byte for byte

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree); follows the T-0069/T-0072/T-0073 pattern |
| Verification | ADR-0015: `/code-review`, one fix round, TL merge gates |
| Branch | `fleet/T-0076-mcgen-dashboard` |
| Created | 2026-11-28 |
| Depends on | T-0065, T-0069 (ADR-0017), T-0072/T-0073 (`OptionsReader`, lint lessons), T-0056 (DB exemplar `store_home`, ADR-0012) |
| Related | plan 02 §2.3–§2.7, P2-06; F-0056 (section blocs, visibility, flag once per visit, analytics); F-0069, F-0072, F-0073 (**lint must cover every role; batch specs fail otherwise**) |

## Goal
Add the DB archetype. The exemplar `store_home` must round-trip. It is the only DB module, so the **probes carry the generalisation proof**: at least two dashboards with different sections.

## Scope
- **In:**
  - `emit/feature_dashboard/` and `bricks/feature_dashboard_*`, a spec for `store_home` (`exemplar: true`), and keep markers (comment-only, few).
  - **The template covers:**
    - N independent sections, each with its own bloc on the shared base, per-section retry, empty and failure states;
    - visibility via `FlowScope.outerIsCurrent`, and a visit lasting as long as the page;
    - a feature flag read once per visit, and an optional section behind a flag;
    - analytics, ADR-0012: sections viewed once per visit, plus item taps;
    - an optional in-flow detail page with paging (the category page);
    - money via `mc_formatters`;
    - the cart-like signed-in section: epoch rule, reload on epoch.
  - **Lint:** it covers every role the emitters read, and archetype errors print the path and message.
  - **Shared code:** reuse `emit/common` with additive changes only. All existing `--check` runs stay up to date.
- **Parallel work:** T-0074 (wire and buildgen) and T-0075 (the FW archetype) are running. Own `emit/feature_dashboard/` and `bricks/feature_dashboard_*`. `archetypes.dart` gets one line.
- **Out:** behaviour changes.

## Acceptance criteria
- **T-0076-AC1:** `mcgen gen store_home --check` exits 0, and a one-field spec change exits 1 and names the file.
- **T-0076-AC2:**
  - `store_home` behaves unchanged: its Bazel tests and the app tests are green.
  - Its diff is markers, spec and manifest only.
- **T-0076-AC3:**
  - Two throwaway dashboard probes generate, analyse clean, and pass BDD under Bazel:
    - one with 3 sections and no detail page or flag;
    - one with 5 sections, a flagged section, a signed-in section and a paged detail page.
  - At least one lint-rejection test per spec role.
- **T-0076-AC4:**
  - These gates pass: `test --lockfile_mode=error //...`, lint, the format gate, `T-0065-AC5_gates.sh`, and every existing `--check` up to date.
  - The lockfiles are unchanged.
  - Every cited test exists.
  - A short finding, with the hand share.

## Log
- 2026-11-28: Created and dispatched (TL), as part of the third wave.
