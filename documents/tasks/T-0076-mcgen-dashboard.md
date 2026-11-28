# T-0076: `mcgen` dashboard (DB) archetype: `store_home` regenerates byte for byte

| Field | Value |
|---|---|
| Status | In Verification |
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
- 2026-11-28 (Engineer, Sonnet): Done on `fleet/T-0076-mcgen-dashboard`.
  - **Archetype** `dashboard` (`lib/src/emit/feature_dashboard/`, brick `feature_dashboard_package`). `store_home` has a spec (`exemplar: true`) and a manifest; its diff is the spec, the manifest, five keep regions and one trailing blank line removed from `store_home_cart.feature`.
  - **No change to `emit/common`.** `archetypes.dart` has one new line.
  - **`flow_scope.dart` is still templated** (`_flowScope` in `flow.dart`): T-0074 had not merged. The TL asked for the contract switch as a follow-up (drop `_flowScope`, the probe script runs `gen`, `wire`, `buildgen`).
  - **Probes** `zz_db_a` (3 sections, no detail page or flag) and `zz_db_b` (5 sections, a flagged `spotlight`, the signed-in cart, a paged detail page): `tool/mcgen/tool/T-0076-AC3_db_probe.sh`.
  - **Tests:** nothing deleted or weakened. `tool/mcgen/test/dashboard_test.dart` is new (19 tests). Pitfalls and hand share: [F-0076](../findings/F-0076-mcgen-dashboard.md).

## Outcome
**Status: In Verification.** `store_home` regenerates byte for byte (63 managed files, 24 owned step stubs). Two throwaway modules generate, analyse clean and pass under Bazel (4 of 4 and 78 of 78 BDD scenarios, plus their architecture, contract and flow-scope tests).

| AC | Evidence |
|---|---|
| T-0076-AC1 | `tool/mcgen/test/dashboard_test.dart`:<br>- `T-0076-AC1 mcgen gen store_home --check exits 0 against the exemplar`<br>- `T-0076-AC1 the round-trip golden: compareToExemplar finds the render identical to the real exemplar`<br>- `T-0076-AC1 a changed spec field makes --check exit 1 and name the file`<br>- `T-0076-AC1 an edit inside a keep region keeps --check green; an edit outside one fails it` |
| T-0076-AC2 | - [gate_test_all.log](../evidence/T-0076/gate_test_all.log): `test --lockfile_mode=error //...`, 246 of 246, including `store_home`'s bdd, contract, flow-scope, golden and architecture tests and the app's<br>- `T-0076-AC2 the keep regions are the taps and the banner helper, and the hand-written files are owned, not rendered`<br>- `T-0076-AC2 gen writes only the manifest into the exemplar, and the committed manifest is the one it writes`<br>- the diff: spec, manifest, five comment-only keep markers (`git diff origin/main -- feature/store/store_home`) |
| T-0076-AC3 | - [T-0076-AC3_db_probe.md](../evidence/T-0076/T-0076-AC3_db_probe.md): gen, `--check`, `build --config=lint` and `test --nocache_test_results` PASS for both probes<br>- `dashboard_test.dart`:<br>&nbsp;&nbsp;- `T-0076-AC3 both probe specs lint clean and render the same bytes in two roots`<br>&nbsp;&nbsp;- `T-0076-AC3 probe A has three sections and no detail page, flag or flags file; probe B has five, a flag and a paged detail page`<br>&nbsp;&nbsp;- lint rejections, one test per role: `T-0076-AC3 an unknown option and a bad section key`, `barrel: it may export only declared ids`, `kinds: a tap kind must be declared, once`, `ids: a type, and used by a method or the detail page`, `detail: its id, kind, call, screen and need`, `params: only navigator methods`, `session section: its call, kind and fetch`, `list section: a tap handler, a fetch, and the flag`, `a section that uses the flow needs the detail page`, `tests options and the strings the page reads`, `a prose slot no template uses fails gen, naming it` |
| T-0076-AC4 | - [T-0065-AC5_gates.md](../evidence/T-0076/T-0065-AC5_gates.md): format gate, analyze, 213 mcgen tests, lockfiles unchanged<br>- [gate_lint.log](../evidence/T-0076/gate_lint.log), [gate_arch.log](../evidence/T-0076/gate_arch.log), [gate_rules.log](../evidence/T-0076/gate_rules.log)<br>- `mcgen gen <m> --check` up to date for `characters_list`, `characters_search`, `discovery_search`, `comics_details`, `characters_details` and `store_home`<br>- [F-0076](../findings/F-0076-mcgen-dashboard.md) |

- **Hand share** (tool/loc): `store_home` source 1,325 hand of 2,452, test 1,339 of 1,690, overall 2,664 of 4,142 (64 %).
- **Keep regions:** `banners.open`, `banners.members`, `categories.open`, `deals.open`, `featured.open`.
- **Follow-ups (for `pending-work.md`):**
  - drop `_flowScope` and switch the probe script to `gen`, `wire`, `buildgen` after T-0074;
  - template the navigator-based steps;
  - a 20-run flake check of the probe targets is not meaningful: they are never committed.
