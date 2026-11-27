# F-0049: Deep-link back stacks, and a flow result that always completes (T-0049)

## Context
P-087: `/characters`, `/comics/:id`, `/search` and `/me/lists/...` were top-level routes, so a cold link opened a one-page stack with no back button. P-092: after a link replaced an open editor, home's New and Edit buttons stayed dead.

## What we learned
1. **A child's path must be relative; the wiring's typed route is absolute.** go_router asserts that a sub-route's path doesn't start with `/`, but `XRoute(...).location` (and so `AppLocations` and every drift test) comes from the `@TypedGoRoute` path, which a wiring writes in full (`/comics/:id`). The routes can't be declared under `HomeRoute` in the wiring: the typed tree must sit in one library, and a wiring never imports `mini_client`. So `app_core`'s `nestUnderHome(appRoutes, entityRoutes)` copies each generated top-level `GoRoute` with its leading `/` removed (children kept) and adds it under home's route. URLs, `location` and the drift tests don't change. A new wiring joins by adding its route list to the list passed in `buildAppRouter`; a route left outside is a one-page stack when a link opens it, and `deep_link_back_stack_test` (one cold link per entity route) fails.
2. **go_router rebuilds the stack for a link, with `go` semantics.** A link to the running app (`pushRouteInformation`) is a `go`: the stack becomes `[home, target]` (or `[home, list, details]` for `/characters/:id`, which was already nested under the list). Whatever was open before is gone, so Back from the target returns to home, never to the old screen. In-app `context.push(AppLocations.x)` from home still stacks `[home, target]` with home below.
3. **go_router never completes the future of a `push` that a `go` replaced.** The `Completer` lives on the imperative match, which `go` discards. A caller awaiting `GoRouter.push` alone waits forever (this froze home's `_awaiting` guard, P-092). **A result future must always complete; with null when the route goes away.** The fix keeps the future outside go_router: `AppFlows` pushes with a `FlowCall` as the `extra` and returns the call's future, and `FlowResultRoute` (given `extra: state.extra` by the wiring's route) completes it with null in `dispose` if no result came. The result path is unchanged (the pop value completes the call through the push future). The call completes once. A route nobody pushed (a link) has no call and nothing to complete.
4. **A cold-link editor now has a page below it.** The `FlowResultRoute` "first route goes home" branch stays as a safety net, but for linked editors `isFirst` is false now, so completing pops back to home.
5. **Tests gotcha:** home's own button is labelled "New reading list" too, so a finder by that text finds the home button and the editor title. Use the editor's key (`reading_list_editor.details`).

6. **Review round hardening.**
   - The result reaches the call directly in `_deliver` (before the pop), not only through the push future, so it never depends on microtask order (a test pushes the route in a plain Navigator, where only the direct path exists).
   - A route opened through `AppFlows` but built without `extra: state.extra` throws a `FlutterError` in debug builds (`FlowResultRoute._debugCheckCall`, run in `didChangeDependencies` because it reads the route's state). `AppFlows` leaves a token per location; the route takes it.
   - `FlowExtraCodec` (set as `buildAppRouter`'s `extraCodec`) encodes a `FlowCall` as null and decodes it as no call, so go_router neither warns on every push nor tries to save a live future. Other extras pass through (the app uses none).
   - `nestUnderHome` rejects a second route at exactly `/`.

## Rule for the bricks
- Every wiring route list goes through `nestUnderHome` in `buildAppRouter`; no entity route is top level.
- A route that ends with a result is built as `FlowResultRoute(extra: state.extra, builder: ...)`, and its caller uses an `AppFlows` entry, which pushes through `FlowCall`.

## Not done
- `/characters/:id` goes Back to the characters list, then home. This is the TL's amended AC1 (plan 01 §4.2 nested paths).
- Plan 01 §4.2's text still says wirings declare the nested tree. The shipped shape is "absolute in the wiring, re-rooted by `nestUnderHome`".
- F-0048 should get one sentence: a result future always completes, with null when the route goes away (the TL owns existing findings).
