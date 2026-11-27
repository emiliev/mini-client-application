# F-0050: A write is pinned to its session epoch from the first send: how to use it, how to test the race, and what a pin cannot tell a guard from

- **Date:** 2026-11-27
- **Author:** crew: Engineer (T-0050)
- **Type:** Design record / Lesson
- **Related:** T-0050, P-083, P-080, P-089, P-093, T-0039, T-0041, T-0048, F-0038, F-0040, F-0046, F-0048

## Summary
`mc_api_auth` can now pin a request to the session epoch its caller checked. A pinned request whose epoch is no longer current is rejected **before any bearer is attached**; nothing reaches the backend and the caller gets `ApiFailure.unauthorized('The session changed')`. `comics_details`' favourite (PUT and DELETE) and all three writes of `library_reading_list_editor` use it. This closes P-083 (the first-send window the T-0048 Verifier reproduced as D1), and the same task pinned P-080, P-089 and P-093.

## 1. The window (why a bloc-side check is not enough)
Dio runs every request interceptor in `Future(() => ...)` (`dio-5.11.1/lib/src/dio_mixin.dart:439`), which is a timer, so **each interceptor starts in a new event-loop turn**. Between the bloc's `_session.epoch == epoch` check and the auth interceptor reading the token, any event can run, a sign-in response for example. Before T-0050 a first send read the token at send time and had no epoch guard (only retries and replays had one), so the POST went out under the new user's bearer. The bloc check shrinks the window and stays as defence in depth, but only the interceptor can close it.

## 2. How to use it (for the bricks)
- **Kit:** `authPinned(epoch)` returns the `Options.extra` map (`{mcSessionEpoch: epoch}`, key `'mc_api_auth.pinned_epoch'`). In `AuthInterceptor.onRequest` a pinned request with `pinned != reader.epoch` is rejected with the same failure as a retry across a session change. It applies whether or not someone is signed in now (a request pinned to a signed-out epoch is rejected after a sign-in too). Unpinned requests and `skipAuthKey` requests (sign-in, refresh, sign-out) are unchanged.
- **Retrofit:** add `{@Extras() Map<String, dynamic> extras = const {}}` to the write's method. The generated code adds it to `_extra` (byte-identical to build_runner, T-0041/T-0048 AC7 checks). The repository takes `required int epoch` and passes `extras: authPinned(epoch)`.
- **Which epoch:** the one the bloc's own check used: the epoch its **shown state** belongs to (`_shownEpoch` in the favourite bloc, `_epoch` in the editor), never `session.epoch` read at the moment of the write. Pinning the current epoch lets a tap on user A's state, handled after B signed in but before the bloc heard of it, write under B's bearer: the pin would carry B's epoch. The favourite bloc therefore drops a tap whose `_shownEpoch` is not the session's epoch (its ending reloads). Pin writes; reads need no pin (their answers are discarded by the epoch check after the await).
- **Failure type:** `ApiUnauthorized`, not a new type. A caller already treats it as "the session is gone" and the editor's `_end` path runs on the epoch check right after. A dedicated type would only add a case every caller must map.
- Feature `lib/` now depends on `//utility/mc_api_auth` (it was a test dependency). `mc_arch_check` allows feature to utility.

## 3. Testing the race
- **Kit (AC1):** `auth_pin_test` drives real Dio and the mocked backend. The caller starts a pinned write and the session switches in the same turn, before Dio's first interceptor runs: no request reaches the backend (`recentTraffic` is empty). On the commit without the guard 4 of the 10 tests failed, the first because the PUT went out under u-101's bearer ([log](../evidence/T-0050/engineer/AC1_before_fix.log)).
- **Features (AC2):** the generic step `{user} signs in just before the app sends {route}` (mc_test_steps) puts a hook at the **front of the root `Dio`**: when the first matching request enters the chain, the session switches in memory, then the request goes on to the auth interceptor. That is exactly the window, deterministic, with no timing luck. Every scenario also ends with `the session belongs to {user}`, so a hook that never fired cannot pass for a survived race (mutation H1).
- **A pin cannot tell a bloc guard from itself.** With the pin in place, a bloc check such as `_canWrite` and the interceptor both stop the request, so a feature test through the real `Dio` cannot show which one held (the T-0048 Verifier's survivors V01 to V03 were exactly this kind). `bloc_guards_test` therefore runs the real `ReadingListEditorBloc` and repository over the mocked backend with **no auth interceptor**: the bloc's check is then the only thing between a changed session and the wire, and the backend's traffic shows it. It is a second place a feature test reaches `src/` (R7), next to the contract test.
- **A `bloc.add` does not run its handler synchronously** (bloc 9): a test that switches the user "right after `add(submit)`" makes the handler see the new session. To let a write start first, hold its answer with a latency profile (`LatencyProfile.slow`) and switch while it is in flight (the V03 test).
- **A session event only reaches a closing bloc if it is queued first.** `close()` awaits the flow subscription's cancel before it cancels the session's, so an event queued *after* `close()` finds no listener (M1 runs before the delivery). The V23 test queues the switch first, then closes, in the same turn.

- **The guard the pin cannot replace** has its own test (`comics_details:bloc_guards_test`): the real favourite bloc over a Dio with no auth interceptor; user A saves, B signs in in the same turn as A's second tap, and 0 DELETEs go out.

## 4. A redundant guard
`ReadingListEditorBloc._load`'s `_loading` flag (P-093 V20) cannot be told from the state check in front of it: the first Retry emits `loading` synchronously, so a second Retry already finds the state is no longer `loadFailed`. Removing the flag alone survives every test (mutation P93-V20-b is marked "equivalent" in the script and must survive). Removing both makes the double-Retry test fail (P93-V20-a). The flag was kept: it is the guard that still holds if the Retry event ever stops depending on the state.

## 5. P-089: the open guard in `comics_details`
`ComicDetailsBloc` ignores a second character or creator hand-over within `openGuard` (500 ms, the same value as `discovery_search`). The guard is keyed by the target (kind and id): the same target within 500 ms is ignored, a different one goes through, so popping back and tapping something else at 450 ms is not swallowed. Pinned from both sides, as in T-0046: a double tap in one frame hands over once, a tap at 499 ms is the same tap, a tap at 501 ms opens again. The cover tap is already idempotent (`_flow.state.cover == null`). The step `I tap the cast member {name} and again after {n} milliseconds` and its siblings are local to the feature.

## 6. The race step must not be vacuous
`{user} signs in just before the app sends {route}` removes its hook once it fired, keeps the sign-in's result, and registers a teardown that **fails the scenario** if no request matched the route (the race was not exercised) or the sign-in failed. `negative_control.sh` points it at a route nobody sends: with the `session belongs to` assertion the scenario goes red, and without that assertion (and without the tap) only the teardown check fails ([log](../evidence/T-0050/engineer/negative_control.log)).

## 7. Mutation harness notes
- `if (_startOpenGuard() | true)` forces a guard to always pass without the analyzer's dead-code warning, which a build break would hide as "not evidence".
- `EXPECT=survive` marks an equivalent mutation: the script fails if it is killed, so a later change that makes the guard load-bearing is noticed.
