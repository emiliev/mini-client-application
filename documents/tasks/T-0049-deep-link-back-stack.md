# T-0049: Cold deep links get a back stack; home's flow buttons survive a link (P-087, P-092)

| Field | Value |
|---|---|
| Status | In Verification |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Opus tier** (app navigation; ADR-0011) |
| Branch | `fleet/T-0049-deep-link-back-stack` |
| Created | 2026-11-27 |
| Depends on | T-0033, T-0041, T-0046, T-0048 (every wiring and `mini_client` routes), T-0037 (`McFlowBackButton`) |
| Related | plan 01 §4.2 ("nested entity paths so deep links rebuild a sensible back stack"), R29; P-087, P-092; F-0020, F-0036, F-0048 |

## Problem
1. **P-087.** `/characters`, `/comics/:id`, `/search` and `/me/lists/...` are top-level routes. A cold link (`miniclient://app/comics/501500`) opens a one-page stack. The outer navigator can't pop, so `McFlowBackButton` renders nothing, and iOS has no system back. The user is stuck.
2. **P-092.** Home clears its "editor open" guard only when `AppFlows` resolves. go_router never completes a `push` that a `go` replaced, so after a link replaces an open editor, the New and Edit buttons stay dead until restart.

## Decision (TL)
- **Nest the entity routes under home**, as plan 01 §4.2 says, so every deep link rebuilds `[home, …]`:
  - `/characters`, `/comics/:id`, `/search` and `/me/lists/new|:id/edit` become `GoRoute`s under `/` in `mini_client`'s route tree.
  - Each wiring keeps owning its route builders and typed locations. Wiring route lists become children of the home route.
  - Keep `AppLocations` paths unchanged. The URLs stay the same, and `AppLocations` drift tests must stay green.
- **No `go`-replaced push may leave a caller waiting forever.** `FlowResultRoute` completes its caller with `null` when it is disposed without a result, whether it was popped or replaced. Home's guard then clears. F-0048 gets a sentence: a result future always completes; with null when the route goes away.
- Navigation changes are Opus-tier for verification.

## Acceptance criteria
- **T-0049-AC1:** Given a cold start from each link, then the first screen shows a back button and tapping it lands on home. The links are:
  - `/characters`
  - `/characters/<id>`
  - `/comics/501500`
  - `/search?q=spi`
  - `/me/lists/new` (signed in)

  Tested at app level (a cold `initialLocation`) and in the e2e (file-drop cold link) with screenshots.
- **T-0049-AC2:** Given a link to a running app (any of the above), then the stack is `[home, target]`. Back returns to home, not to whatever was open before, unless go_router's semantics say otherwise; document which. Existing link tests (T-0035, T-0033 and after) stay green.
- **T-0049-AC3:**
  - **Replaced editor:** given an open editor (New reading list) replaced by a link to home, when I tap New reading list again, then the editor opens. The awaiting caller got `null`.
  - **Dismissed without a result:** given `FlowResultRoute` disposed without a result in any way (pop, replacement, `go`), its future completes once with `null`.
- **T-0049-AC4:**
  - Every wiring's drift test passes (`AppLocations.x == XRoute(...).location`).
  - `mc_arch_check`, the fixtures check, `test //...`, lint, `rules_fork.sh check` and format pass.
  - The full mini_client e2e passes: characters, comics, search, reading-list journeys, and every deep link.
  - Globs use `MC_GENERATED_DART`.

## Log
- 2026-11-27: Created and dispatched (TL).
- 2026-11-27: Engineer (Sonnet) implemented and handed off. Review-first applies.

## Outcome
**What changed**
- `app_core`: new `nestUnderHome(appRoutes, entityRoutes)` (`route_nesting.dart`) re-roots each wiring's absolute `GoRoute` under home (leading `/` removed, children kept). `buildAppRouter` passes every wiring's routes through it. URLs, typed `location`s and `AppLocations` don't change; every wiring's drift test is green.
- `FlowResultRoute` takes `extra: state.extra`. `AppFlows` pushes with a `FlowCall` as the `extra` and returns the call's future. The route completes the call with null in `dispose` when no result came (popped, replaced by a `go`, removed). The two library routes pass `extra: state.extra`.
- Home's guard needed no change: it clears when the future completes.

**AC to evidence**
- AC1: `app/mini_client/test/deep_link_back_stack_test.dart` (`T-0049-AC1 a cold start from <link> ...`, five links, each taps Back to home); `app_core/test/route_nesting_test.dart`; e2e cold links with screenshots in `documents/evidence/T-0049/engineer/mini_client/` (`05`, `18`, `36`, `37`, `55` and their `*b`/`*c` Back-to-home shots).
- AC2: same test file (`T-0049-AC2 a link to the running app (<link>) stacks [home, target]`, with the characters list open first). Documented in F-0049: a link is a `go`, so Back from the target is home, never the screen that was open.
- AC3: `deep_link_back_stack_test` (`T-0049-AC3 a link to home replaces an open editor ...`); `app_core/test/flow_results_test.dart` group `T-0049-AC3` (replaced by `go`, `go` elsewhere, Back, result then leave, no caller); e2e `reading_list_deeplink_test` (37c).
- AC4: `documents/evidence/T-0049/engineer/T-0049-AC4_gates.md` (146/146 tests, lint, `mc_arch_check`, fixtures check, `rules_fork.sh check`, format, l10n; coverage mini_client 95.4 %, app_core 96.4 %, wirings 100 %). Full mini_client e2e 10/10 (`mini_client/e2e-summary.md`).
- Mutations: `documents/evidence/T-0049/engineer/mutations.sh`, 11/11 killed (`mutations.log`), including a route back at the top level (one per wiring) and the null completion.

**Test integrity:** nothing deleted, skipped or weakened, no `// ignore:`. `flow_results_test.dart`'s two route builders now pass `extra: state.extra` (needed to test the new path). One redundant line (completing the call on delivery, equivalent to the push future's) was removed after a mutation survived.

**Decisions for the TL**
1. **`/characters/<id>` Back goes to the characters list, then home**, not straight to home (the details route nests under the list since T-0033). AC1's wording says "lands on home"; the test and e2e check list then home. Making it straight to home means un-nesting details from the list (an in-app tap on a card still pushes). Say if you want that.
2. **Plan 01 §4.2 and F-0048** need a sentence each (TL-owned): the nesting is done by `nestUnderHome` in the app shell, not by the wirings' typed trees (F-0049 item 1); a result future always completes, with null when the route goes away.
3. e2e files edited: five cold-link targets now also tap Back; new target `character_details_deeplink_test.dart`.

**Finding:** [F-0049](../findings/F-0049-deep-link-back-stack-and-result-futures.md).
