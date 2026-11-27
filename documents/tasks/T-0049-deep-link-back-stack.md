# T-0049: Cold deep links get a back stack; home's flow buttons survive a link (P-087, P-092)

| Field | Value |
|---|---|
| Status | In Progress |
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
