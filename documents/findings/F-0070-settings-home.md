# F-0070: The settings index: a parent route over an existing child, a session-following page with a profile read, and what the nesting changed

- **Date:** 2026-11-28
- **Author:** crew: Engineer (T-0070)
- **Type:** Design record / Lesson
- **Related:** T-0070, T-0063 (F-0063), T-0066 (F-0066), T-0049 (F-0049), ADR-0012, ADR-0013, ADR-0015

## Summary
`settings_home` is the settings index (`/settings`): Account (who is signed in, Sign in / Sign out), Appearance (a row with the current theme as its subtitle) and About (version and build, and the mocked backend's seed). `/settings/appearance` is now a **child** of `/settings`, so a link or a push builds home, settings, appearance, and Back walks that stack. The URL did not change.

## 1. The shape
- One flow with one page (`settings_home`, the route's name, so it is tracked once: ADR-0012). The flow state is an empty class: there is nothing to keep between pages, so it has no freezed file.
- One bloc, `loading` / `ready(account, themeMode, about, busy)`. It has no failure state: nothing on the page can fail to show.
- The navigator has three intents: `openAppearance()`, `requestSignIn()`, `signOut()`.
- **Sign out goes through the navigator, not through `mc_session`.** The feature only **reads** the session (`SessionReader`, with `authState` and the epoch). The wiring implements `signOut()` with `AuthApi.signOut()`, the call home's entry already makes: it ends the session at once and tells the server. A `SessionWriter.signOut` in the feature would skip the server call and give the feature a write port. The architecture test forbids `SessionWriter` and `AppearanceSettings` (the writer) in the package.
- The theme subtitle follows `AppearanceReader.changes` (the reader port: the feature never changes the appearance), so a theme chosen on the Appearance page is there when Back returns.

## 2. Who is signed in: one read, pinned to the epoch
- The session has only a user id. The name and email come from `GET v1/me`, read with `Options(extra: authPinned(epoch))` by `AccountProfileReader` (a plain Dio call: one request does not justify a retrofit API).
- The page shows `Signed in as <id>` at once and upgrades to the name when the profile arrives. A failed read leaves the id: no error screen, nothing reported.
- **The epoch rule (F-0063 §4, F-0040 fact 21):** the epoch is read before the request, and checked after it. An answer for a session that is gone is **dropped before any state is written**, and the page is asked to show the session now current. Proved both ways with a held request: the user switches (the old user's name never shows), and the user signs out (the late answer does not bring the user back). The mutant that removes the check fails the first scenario.
- A same-user re-sign-in starts a new epoch but sends no `authState` event. The page keeps the profile it has (same user), so nothing is read twice.
- **Sign in** awaits the navigator, one at a time (a double tap asks the app once). **The session, not the answer, decides** what shows next. A throwing navigator is reported (`addError`) and the button comes back. Sign out is the same.

## 3. Nesting an existing typed route under a new parent
- The child stays a typed route with its own class; only the annotation moves: `@TypedGoRoute<SettingsHomeRoute>(path: '/settings', routes: [TypedGoRoute<SettingsAppearanceRoute>(path: 'appearance')])`. The child's path is **relative**, as go_router requires; go_router_builder still generates `location == '/settings/appearance'`, so `AppLocations.settingsAppearance`, the drift test and the deep link are unchanged.
- `nestUnderHome` copies the generated top-level route with its children, so the whole tree sits under home. A cold link to `/settings/appearance` gives `[home, settings, appearance]`: tested in `account_wiring:routes_test` and in the real app (`settings_route_test`, and the e2e).
- **Opening Appearance from the index is a `push` of the same location**, so the stack is `[home, settings, appearance]` as well, and Back from either lands on the index.
- **Tests that assumed `/settings/appearance` sits on home had to change** (listed in T-0070's Outcome): every route-stack assertion that went Back from Appearance straight to home now goes to the index first, and the wiring's route-set assertion lists `/settings` plus the relative `appearance`.

## 4. Smaller facts
- **`requestAppSignIn` took a required `purpose`.** The settings index has no reason of its own ("Sign in to sync your appearance" would be wrong), so `purpose` is nullable now: the sign-in screen says nothing about why. This avoided a new `SignInPurpose` (which would also change `auth_signin`'s reasons, strings and tests).
- **`AppConfig` had no app version.** It gained an optional `version` (null when absent or not a string), and `dev`, `e2e` and `perf` configs say `0.1.0`. About shows `0.1.0 (build 1)`, or `Build <build>` when there is no version. The test container's config has no version, so BDD covers the build-only form; the real-app test covers the full line.
- **A sign-in form never settles in a widget test** (F-0066 §7): `settleIo`'s `pumpAndSettle` times out while the form's request is on its way. `settings_route_test` has `pumpIo`, which alternates real time and 100 ms pumps until a condition holds.
- **`ListTile` keys, not column keys:** the BDD step `the row {'appearance'} reads {..}` reads a `ListTile`'s subtitle by its key; a key on a surrounding `Column` would find no tile.
- The pseudo-locale file is generated by the same letter map as T-0063's (accents, brackets, `~` padding of 40 %), with placeholders left alone.

## Not done
- No settings entries beyond Account, Appearance and About (accessibility, language, notifications, account deletion: out of scope).
- The profile is read on every visit of the index for a user it does not know yet; it is not cached across visits (the page's bloc is created with the page).
