# F-0061: Identity preferences: optimistic concurrency, a fixed check order, and a held two-client probe

- **Date:** 2026-11-27
- **Author:** crew: Engineer (T-0061)
- **Type:** Design record / gotcha
- **Related:** T-0061, T-0039, T-0047, T-0051, F-0050 §7, F-0051, plan 01 U43, P1-22 AC6

## Summary
`mc_fixtures_identity` now serves `GET` and `PATCH /v1/me/preferences` for the `settings_appearance` exemplar. The choices below are the ones the next fixture package with a versioned write should reuse.

## Design facts worth reusing
- **One check order, written down and pinned pair by pair.** Bearer (401), body shape and `ifVersion` (`invalid_body`), unknown keys, empty patch, the values in the order `themeMode`, `density`, `reduceMotion`, and only then the version (409). The version is last on purpose: a client that sends garbage learns about the garbage, not about a conflict it cannot fix by re-sending. The test lists 17 pairs ("A beats B"), so swapping any two adjacent checks is caught.
- **`unknown_key` comes before `empty_patch`.** A body `{ifVersion, x}` has no preference key, but the useful answer is the unknown key.
- **`updatedAt` is `clock + version seconds` per user**, not a backend-wide tick as in `mc_fixtures_library`. Version 0 shows the clock, a user's first write shows `+1 s`, and one user's writes never move another's `updatedAt`. Tests can compute it from the version alone. This deliberately differs from T-0047's backend-wide tick: with a global counter a user's `updatedAt` would depend on how many writes other users made first, which makes per-user assertions order-dependent. The Tech Lead accepted the difference in the review round.
- **A write with identical values still bumps the version.** The server does not diff; `ifVersion` guards the object, not the content.
- **`version_conflict` carries the current object in `error.current`.** `extra` keys are spread after `code` and `message` (F-0051 §1), so the key is `current`, never `code`.
- **`preferences_conflict` is a handler override, not a `FailureRule`**, because a rule's body is the fixed `injected_failure` and cannot carry `current`. The "fired" flag lives in the backend store and is cleared by a new engine hook, `MockScenario.onSelect`, which `MockBackend.useScenario` calls on every selection. So each selection arms it once, with or without `reset()`; the first version of this task cleared it only on `reset()`, which a review caught. A scenario with a once-only handler effect needs this hook, because `useScenario` otherwise leaves the store alone. The injected 409 has its own message, so it is not confused with a real mismatch (it used to read "at version 0, not 0"). It is consumed only by a request that reaches the version check (auth and validation failures do not use it up), and it writes nothing. A client that retries with `current.version` therefore succeeds.
- **`identity.preferences_error` is a pair of `FailureRule`s** on exactly the two preferences routes, so it answers the engine's own `injected_failure` body and `/v1/me`, favourites and the auth routes keep working. `identity.server_error` (built from `routeManifest`) gained the two routes without any test edit.
- **Seeds are in every set**, including `identity.empty` ("empty" there means favourites). `u-101` is `themeMode: dark` at version 0, so a test has a user whose preference differs from the default without writing first.

## Testing a race with a held request
A mock backend answers each request in one synchronous handler, so two requests can only race at the transport. `preferences_test.dart` has a `_HoldingAdapter` that wraps `backend.adapter` and parks a request marked with an `x-hold` header **before** the handler runs, on a `Completer`. The test awaits `arrived` (the request is certainly in flight), lets a second client complete a write, releases the gate, and the held request meets the new version: 409 with the winner's object. There is no timer and no sleep, so it cannot flake on a loaded machine. A second test sends two PATCHes with `Future.wait` and asserts only the invariant (statuses `[200, 409]`, the loser's `current` is the winner's body, the final state is the winner's), because which of the two arrives first is the adapter's business.

## Oracle
`_Model` at the bottom of the test file is a flat decision list (if-chain in the order of the CONTRACT table) written without the handler's helpers. A 300-step seeded random sequence of valid, stale, malformed and unknown-key patches runs against both and compares status, code, the full object, and a following `GET`. The test asserts that all eight outcomes were reached, so it cannot pass by never producing a 409.

## Mutation harness
`documents/evidence/T-0061/engineer/mutations.sh` follows F-0050 §8 and F-0051 §2: it refuses a dirty package, sets its restore trap before the first edit, formats each mutant, and counts `Build did NOT complete` as broken (never killed), only `FAILED in` as killed.
