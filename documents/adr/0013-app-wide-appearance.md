# ADR-0013: The app-wide appearance lives in `mc_appearance`, local first, synced with the account

- **Status:** Proposed (drafted by the T-0063 Engineer; the TL accepts or edits it at the merge)
- **Date:** 2026-11-27
- **Deciders:** Tech Lead
- **Related:** T-0063, T-0061, T-0050, T-0052, ADR-0007, ADR-0012, F-0050, F-0061, F-0063, P1-22, plan 01 F056

## Context
`settings_appearance` (T-0063) is the first ST exemplar. Its three choices (theme mode, density, reduce motion) are not the screen's own: the **whole app** must apply them at once, before any feature is opened, and they must survive a restart. Signed in, they follow the user through the identity preferences routes (`GET`/`PATCH /v1/me/preferences`, `ifVersion`, a `409` with `current`; T-0061). Every later ST brick that holds app-wide state (`settings_language`, `settings_accessibility`) will copy where this lives and how it syncs, and `McApp` is shared by every app, so the choice is costly to reverse.

Forces:
- **R15.** The bloc that changes the values is pure Dart, so the state it talks to must be pure Dart too; `McApp` is Flutter.
- **R4 and layering.** A feature cannot export state to the app or to other features: it exports a flow and a navigator only.
- **Boot.** `McApp` creates its router once boot is ready (R29); nothing feature-side exists before that.
- **The mocked backend forgets everything when the app is killed** (ADR-0005: it is in-process). A signed-in restart therefore meets an account that is back at its seed.
- **Tests.** Every feature test that signs in would otherwise send a preferences read it never asked for, and a storage write still running at teardown is a known flake (F-0050 §7).

## Options considered
### Where the state lives
#### A. A pure-Dart utility, `utility/mc_appearance` (UF), in the root container (chosen)
- Pros: one instance for the whole app, created at boot (before the router), readable from blocs (port) and from `McApp` (`app_core` maps it to Flutter). Features depend on a utility, as the layering wants. The sync runs whether or not the settings screen was ever opened.
- Cons: a new package; its wire format sits outside the feature that shows it.

#### B. In the feature, exported through its barrel
- Cons: breaks R4 (only flows, navigators and arg types are exported) and layering (`app_core` and other features would depend on a feature). Nothing would sync before the screen opens.

#### C. Extend `mc_ds_theme` (`McThemeModeController`)
- Cons: a Flutter package (R15), and a design-system package would gain storage, session and network dependencies.

### How `McApp` reads it
- **(a) The root container's `AppearanceReader`, read once boot is ready, then followed (chosen).** `McApp(appearance:)` defaults to `McApp.rootAppearance`; a test passes its own.
- (b) Pass a controller in from `main`: the app would have to build storage before DI, duplicating the root list.

## Decision
1. **`utility/mc_appearance`** (pure Dart) holds the `AppearancePreferences` (theme mode, density, reduce motion) behind two ports: `AppearanceReader` (`snapshot`, `changes`) for the app shell, and `AppearanceSettings` (`change`, `reset`, `retry`) for the settings feature. `AppearanceDIInitializer` is in `rootInitializers` after the feature flags (it needs `Dio` with the bearer, the session, the store and monitoring) and never waits for the network.
2. **The device's copy is the truth when signed out.** Every change is applied in memory and saved under `appearance` in `mc_storage` **synchronously** (`FileStore.readSync`/`writeSync`, new) before `change` returns. So the saved choice is known before the first routed frame, no save is ever still running when a test deletes its directory, and nothing awaits real I/O under fake time. A failed save is shown (`saveFailure`), the change still applies, and Retry saves again.
3. **The merge rule on sign-in** (every new session epoch: a sign-in, a signed-in launch, a user switch, a same-user re-sign-in). The account's copy is read and **the account wins, except for the settings changed on this device and not yet confirmed** ("pending", saved with the user they belong to), which are re-applied on top and sent:
   - pending settings of the user now signed in, or made while signed out, go to this account (so "Sync across devices" keeps what the user just chose);
   - pending settings of **another** user are dropped: A's unsynced choice never reaches B's account;
   - an account at an **older version** than this device last saw it at, for the same user, has lost a write (a restored backend; the mocked one after every kill). The device's copy is the newest known and is sent again. An account at a newer version moved on (another device): it wins.

   On sign-out the shown values stay on the device (they are the device's now) and what was pending is dropped. A switch A → B is a sign-out then a sign-in: A's last values show until B's copy arrives, and B's copy replaces them.
4. **Writes.** One request at a time; a `PATCH` sends only the pending settings, with `ifVersion` = the version last read, pinned with `authPinned` to the epoch its check used (T-0050). The epoch is checked **after every await, before anything is applied or written**, so an answer for a session that is gone changes nothing. A change made while a request is out is sent after it.
5. **The 409 policy.** On `409 version_conflict` the account's `current` is taken, only the user's pending settings are re-applied on it, and the `PATCH` is sent **once more** on `current.version`. If `current` brought another device's change in a setting the user did not touch, the status ends `conflictResolved`; otherwise `synced`. A second `409` in a row ends `offline` (the change kept, pending, and sent with the next change or Retry). Any other failure is `offline` too: **an error never blocks a local change.**
6. **What each setting affects** (`app_core`, `McAppearanceFlutter`):
   - **Theme mode** → `MaterialApp.themeMode` (System follows the platform's brightness). The boot page, which exists before the appearance, uses the platform's.
   - **Density** → `ThemeData.visualDensity` of all four themes (`McTheme.of(variant, visualDensity:)`; Compact is `VisualDensity.compact`, Comfortable the platform default). Material widgets size themselves by it (list tiles, switches, buttons); a screen reads `Theme.of(context).visualDensity` to tighten its own spacing (the settings screen does). The DS's own widgets do not read it yet.
   - **Reduce motion** → `MediaQuery.disableAnimations` for everything under the router (pages and overlays), on top of the platform's setting, never turning that back off. The DS reads it through `McA11y` (the charts' draw-in, `McImage`'s fade, every `McA11y.duration`). Flutter's route transitions and the theme cross-fade do not read it.
7. **Status** is one of `local` (signed out), `pending`, `synced`, `offline`, `conflictResolved`.
8. **Tests.** `McTestContainer` registers the real `Appearance` with `followAccount: false` by default (no request, status `local`), as it stubs the flags for `/v1/flags`; a package whose tests are about the sync sets `McTestContainer.appearanceFollowsAccount = true` in its `setUpAll` (`settings_appearance`).

## Consequences
- **Positive:**
  - The whole app re-themes at once from one source, with no restart, and starts in the saved theme.
  - The merge rule, the 409 policy and the epoch pin are in one place, pinned by `mc_appearance`'s solitary tests (races in both orders with held requests) and the feature's BDD.
  - The ST bricks for app-wide settings copy the shape: a pure-Dart utility in the root container, ports for the shell and the bloc, a synchronous device copy.
- **Negative / trade-offs:**
  - The preferences' wire format lives in the utility, not the feature (no retrofit API in the ST feature; its "2 endpoints" are the utility's).
  - Synchronous file I/O on the UI isolate, for one small file per change. Only for tiny values; documented on `FileStore.writeSync`.
  - The "older version" rule relies on versions never going back in a healthy server; against a real backend it only fires after a restore.
  - The boot page does not follow the saved theme (it exists before the appearance).
- **Follow-ups:**
  - DS widgets could read the density (`McSegmented`, `McButton`) instead of each screen.
  - `settings_home` (the settings index) and an `account_sandbox` (P1-22 lists it).
  - If the mocked backend ever persists its state across launches, the "older version" rule stops firing in the app and stays as a guard.
