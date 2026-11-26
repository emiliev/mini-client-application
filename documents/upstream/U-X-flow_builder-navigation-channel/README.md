# U-X-flow_builder-navigation-channel: flow_builder swallows deep links

| | |
|---|---|
| Target | https://github.com/felangel/flow_builder (issue, with a PR) |
| Task | T-0035; finding F-0034; vendored in `third_party/flow_builder` |
| Status | Draft, not sent (Q-013) |

## Issue: "Mounting a FlowBuilder breaks deep links: the `flutter/navigation` handler is replaced and never restored"

**Body:**

`FlowBuilder` (0.1.0, `lib/flow_builder.dart`, `_SystemNavigationObserver.add`) calls
`SystemChannels.navigation.setMethodCallHandler(_handleSystemNavigation)` in `initState`
and never restores the framework's handler. The replacement handles `popRoute` and
`pushRoute` only and answers anything else with `null`. Since Flutter 3.10 the engine
sends deep links as `pushRouteInformation`, and the framework's own handler
(`WidgetsBinding._handleNavigationInvocation`) passes those to
`WidgetsBindingObserver.didPushRouteInformation`, which is how `Router` (and so
go_router, `MaterialApp.router`) receives them.

Result: once any `FlowBuilder` has mounted, every deep link sent to the running app does
nothing, for the rest of the process, even after the flow is gone. Cold-start links and
links during boot still work (they arrive before the first flow).

Repro (widget test):

```dart
// MaterialApp.router with a RouterDelegate that records setNewRoutePath,
// and a FlowBuilder somewhere in the tree.
await tester.pumpWidget(app);
await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
  'flutter/navigation',
  const JSONMethodCodec().encodeMethodCall(
    const MethodCall('pushRouteInformation', {'location': '/x'})),
  (_) {},
);
// expected: setNewRoutePath('/x');  actual: never called
```

Our fix is small (see `third_party/flow_builder/0001-navigation-channel-and-popscope.patch`
in the mini-client repo): handle `pushRouteInformation` by passing `location` to
`WidgetsBinding.instance.handlePushRoute`, and answer an unknown method with `false`.

Our vendored patch has two known limits, both deliberate: it cannot restore the
framework's handler (that handler is private to `WidgetsBinding` and not readable), and
it drops the `state` of `pushRouteInformation` (`handlePushRoute` takes a location only;
iOS sends none). It also answers an intercepted `popRoute` with `true` instead of `null`,
because iOS counts any other reply as unhandled.

A better fix, if you are willing: do not replace the channel handler at all. Register a
`WidgetsBindingObserver` whose `didPopRoute` runs the interceptors, so `Router`,
`didPushRouteInformation` and every method added to the channel later keep working.
(Ordering relative to other observers changes, which is why we did not do it.)
Failing that, keep the framework's handler and delegate to it.

## Second issue (found in mini-client T-0036): a stale `PopScope` after a state update

`_FlowBuilderState._canPop` is `_pages.length > 1 || (_navigator?.canPop() ?? false)`, read
in `build`. When the flow's state moves back to a single page through
`FlowController.update`, `build` runs while the `Navigator` still holds the old routes, so
`canPop` is still true and `PopScope(canPop: false)` stays mounted. Nothing rebuilds the
flow afterwards, so the next pop (a back button's `maybePop`, or the iOS edge swipe) is
swallowed. We recompute `_canPop` in a post-frame `setState` after each state update, and
mount the `PopScope` always (`canPop: !condition`) instead of swapping the widget.

The same stale read exists in `didUpdateWidget`: when the parent passes a new `state` (or
`controller`), `_pages` is replaced and `build` reads `_canPop` before the navigator has the
new routes, so going from two pages to one leaves `PopScope(canPop: false)` mounted and the
next pop is swallowed. The fix is the same post-frame `setState` as in `_listener` (mini-client
T-0037, patch change 5); a test is a `FlowBuilder(state: n, ...)` inside a pushed route whose
`n` goes from 1 to 0, followed by a `popRoute`.
