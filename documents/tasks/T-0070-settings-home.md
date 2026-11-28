# T-0070: `settings_home`, the settings index with a `/settings` parent route (F055)

| Field | Value |
|---|---|
| Status | In Verification (handed off for `/code-review` and the merge gates, ADR-0015) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verification | ADR-0015: `/code-review`, one fix round, TL merge gates |
| Branch | `fleet/T-0070-settings-home` |
| Created | 2026-11-28 |
| Depends on | T-0063 (`settings_appearance`, ST exemplar), T-0066 (sign-in, `requestAppSignIn`), T-0049 (`nestUnderHome`) |
| Related | plan 01 F055 ("Settings index", B + ST+, `mc_session`); P-119 (`settings_home` and the `/settings` parent route); F-0063, F-0066 |

## Goal
Home's "Settings" entry opens Appearance directly today. Give settings a real index screen:
- **Account:** who is signed in, with a Sign in / Sign out action.
- **Appearance:** opens the existing screen, showing the current theme as a subtitle.
- **About:** app version and build, and the mocked backend's seed.

`/settings/appearance` then sits under `/settings`, so Back from Appearance goes to Settings, then home.

## Scope
- **In:**
  - **`feature/settings/settings_home`, in the shapes of `settings_appearance`.**
    - **Flow and navigator:** `SettingsHomeFlow` has one page. `SettingsHomeNavigator` exposes:
      - `openAppearance()`
      - `requestSignIn()`
      - `signOut()` (or the feature uses `mc_session` through the existing auth port; pick one and document it)
    - **State:** one bloc. It follows the session (epoch rule) and `mc_appearance` for the subtitle.
    - **About:** values come from `AppConfig`.
    - **Tests and strings:** l10n in en and de. BDD tests, plus unit tests for pure logic. **No goldens** (ADR-0015).
    - **Analytics:** the screen is named `settings_home` (ADR-0012).
  - **`account_wiring`:**
    - The `/settings` route nested under home, with `/settings/appearance` as its child. The URL stays the same, but the stack becomes home → settings → appearance.
    - `AppLocations.settings` and its drift test.
    - Home's Settings entry opens `/settings`.
    - A cold link to `miniclient://app/settings/appearance` walks Back to Settings, then to home.
- **Out:** other settings pages (accessibility, language, notifications), account deletion.

## Acceptance criteria
- **T-0070-AC1:**
  - Signed out, the index shows "Not signed in" with Sign in, the Appearance row with the current theme, and About with version and seed.
  - Signed in, it shows the user and Sign out.
  - BDD.
- **T-0070-AC2:**
  - Sign in from the index awaits the sign-in flow, and on success shows the user.
  - Sign out ends the session, and the index updates.
  - Switching users while the index is open shows the new user; a stale load is dropped.
  - BDD.
- **T-0070-AC3:**
  - The Appearance row opens Appearance. After changing the theme and going Back, the subtitle shows the new value.
  - Wiring tests cover the route tree and locations, and a cold link to `/settings/appearance` gives the stack home → settings → appearance.
  - The existing `settings_appearance` tests stay green and unedited, except route-stack assertions that must now include `/settings` (list them).
- **T-0070-AC4:**
  - `de` and `en_XA` render at 1× and 2× with no overflow.
  - E2E on your own simulator: home → Settings → Appearance → Dark → Back (the subtitle says Dark) → Back → home. Then the cold link, with Back twice. Take screenshots.
- **T-0070-AC5:**
  - Gates: `test --lockfile_mode=error //...`, lint, `mc_arch_check`, `rules_fork.sh check`, the format gate, `l10n_check`, and `T-0042-AC4_safety.sh` after `tool/ide_sync`.
  - The 50-run flake check on the session and appearance targets.
  - Every cited test exists.

## Log
- 2026-11-28: Created and dispatched (TL), as part of the second hybrid wave.
- 2026-11-28: Engineer (Sonnet). Branch `fleet/T-0070-settings-home` from `origin/main` `c1b08371`.
- 2026-11-28: Built `feature/settings/settings_home` (flow, navigator, one bloc, page, en/de/en_XA), the `/settings` parent route in `account_wiring` (the appearance route moved under it), `AppLocations.settings`, home's entry, and `AppConfig.version`. Decisions are in [F-0070](../findings/F-0070-settings-home.md).
- 2026-11-28: **Decision, sign out:** the navigator has `signOut()`, implemented with `AuthApi.signOut()` (as home does); the feature only reads the session. **Decision, name and email:** one `GET v1/me`, pinned to the epoch, dropped when the session changed.
- 2026-11-28: **Shared edits beyond `AppLocations` and home**, all small: `requestAppSignIn(purpose:)` is nullable (the index has no reason of its own), and `AppConfig` has an optional `version` (`dev`, `e2e` and `perf` configs say `0.1.0`). Also `tool/l10n_check` (BUILD data and a gate test) and the workspace `pubspec.yaml`.
- 2026-11-28: One manual probe, not kept in the suite (ADR-0015): removing the epoch check after the profile read made the scenario "the user switches while the first profile read is on its way" fail, as it should.

## Outcome
**Handed off** for `/code-review` and the TL's merge gates. Finding: [F-0070](../findings/F-0070-settings-home.md). Evidence: [`documents/evidence/T-0070/`](../evidence/T-0070/).

### What was built
- **`feature/settings/settings_home`** (new): `SettingsHomeFlow` (one page, the screen `settings_home`), `SettingsHomeNavigator` (`openAppearance()`, `requestSignIn()`, `signOut()`), `SettingsHomeBloc` (`loading` / `ready(account, themeMode, about, busy)`), `AccountProfileReader` (`GET v1/me`, pinned to the epoch), `AboutInfo` from `AppConfig`, strings in en, de and en_XA (15 keys). The page is `McAppBar` with `McFlowBackButton`, an account row with Sign in or Sign out, an Appearance row with the theme as its subtitle, and the About rows.
- **`account_wiring`**: `SettingsHomeRoute` (`/settings`, `settings_home`) with `SettingsAppearanceRoute` nested under it (relative path `appearance`, location unchanged), `SettingsHomeNavigatorImpl`, `AccountRouteTargets.settingsHome()`.
- **`app_core`**: `AppLocations.settings`; `requestAppSignIn(purpose:)` is nullable.
- **`mini_client`**: home's Settings entry pushes `/settings`.
- **`mc_config`**: optional `AppConfig.version`.

### AC → evidence
Every test below was grepped at the handoff commit.

| AC | Tests and evidence |
|---|---|
| AC1 | BDD (`settings_home:bdd_test`): "Signed out, the index shows Not signed in with Sign in, Appearance with its theme, and About"; "Signed in as the collector, the index shows the user and Sign out"; "The profile cannot be read: the user is named by id, and the page still works"; "The Appearance row shows the theme chosen elsewhere, also after a sign-out". `unit_test`: "About reads version, build and the backend seed from the config", "the profile is read from the body of GET v1/me …". `mc_config:app_config_test` "T-0070-AC1 version is optional …". `contract_test` "the screen is valid analytics snake_case and equals the route's name". Real app: `mini_client:settings_route_test` "T-0070-AC1 the index in the real app: signed out …" (the line `0.1.0 (build 1)`, seed 42). |
| AC2 | BDD: "Sign in waits for the app, then the index shows the user"; "Backing out of sign-in …"; "A sign-in that breaks is reported …"; "A double tap on Sign in asks the app once"; "Sign out ends the session, and the index shows Not signed in"; "A double tap on Sign out asks the app once"; "A sign-out that breaks is reported, and the user stays signed in"; "The session ends elsewhere …"; "Another user signs in while the index is open: it shows the new user"; "The user switches while the first profile read is on its way: the late answer is dropped" (held `GET /v1/me`, 2 GETs, no error); "Signing out while the profile read is on its way: the late answer does not bring the user back". `unit_test` "a signed-in account is named by its profile, else by id …". `account_wiring:routes_test` "T-0070-AC2 settings requestSignIn …" and "T-0070-AC2 settings signOut ends the session through the auth port, and tells the server". Real app: `settings_route_test` "T-0070-AC2 the index in the real app: Sign in opens the sign-in screen, signing in shows the user, and Sign out ends the session". |
| AC3 | BDD "The Appearance row asks the app to open the appearance settings". `account_wiring:routes_test`: "T-0063-AC3 T-0070-AC3 /settings/appearance builds the appearance flow, with settings below it, and home below that" (the cold-link stack), "T-0070-AC3 /settings builds the settings index with home below it", "T-0070-AC3 the Appearance row pushes the appearance settings above the index, and Back returns to the index", "T-0070-AC3 a link to /settings/appearance replaces what was open …", "T-0070-AC3 the link form of /settings normalises to the route", "T-0063-AC3 T-0070-AC3 every AppLocations entry of the group equals its typed route" (the route tree: `/settings` with the one child `appearance`). Real app (`settings_route_test`): "T-0063-AC6 T-0070-AC3 home's Settings entry opens the index, its Appearance row opens the appearance, and Dark re-themes the whole app …" (after Back the subtitle says Dark), "T-0063-AC5 T-0070-AC3 miniclient://app/settings/appearance cold opens … Back goes to the index, then home", "T-0070-AC3 miniclient://app/settings cold opens the index …". `analytics_screens_test` lists `settings_home` among the route names. `settings_appearance`'s own tests are unedited (the diff of `feature/settings/settings_appearance` and `utility/mc_appearance` is empty). |
| AC4 | BDD "In German every string of the index is German" and "In the pseudo-locale nothing overflows at <scale>x text" (1 and 2, signed in and signed out). `flow_scope_test`: "the index builds in <variant> …" (4 themes) and "at <scale>x text, Compact tightens the gap between sections, and nothing overflows" (1.0 and 2.0). `contract_test` "every theme mode has its own label in <locale>" and the version line in both locales. E2E on a fresh `mc-T-0070-engineer-75680` simulator (deleted): [summary](../evidence/T-0070/e2e/e2e-summary.md), 3/3 PASS. `settings_journey_test`: home → Settings → Appearance → Dark → Back (the index says Dark) → Back → home, then characters, relaunched still dark (screenshots 59 to 64, with `61b_settings_index_dark`). `settings_signed_in_test` (65 to 67). `settings_deeplink_test`: the cold link, Back to the index, Back to home (68, 68b, 68c). |
| AC5 | Gates, all green on the branch: `test --lockfile_mode=error //...` ([241/241](../evidence/T-0070/test_all.summary.txt)), [lint](../evidence/T-0070/lint.log), [mc_arch_check](../evidence/T-0070/arch_check.log), [rules_fork.sh check](../evidence/T-0070/rules_fork.log), [format gate](../evidence/T-0070/format_gate.log), [l10n_check](../evidence/T-0070/l10n_check.log), [T-0042-AC4_safety.sh after tool/ide_sync](../evidence/T-0070/T-0042-AC4_safety.md). [50-run flake check](../evidence/T-0070/runs_per_test_50.txt): `settings_home`, `settings_appearance`, `mc_appearance`, `mc_session`, `mc_config`, `account_wiring` and `settings_route_test`, 22 of 22 targets pass 50 of 50. `architecture_test` (barrel, R15, no writer port, no `SessionWriter`); `l10n_check:workspace_gate_test` "T-0070-AC5 the gate checks the settings_home ARB set". |

### Changed existing tests (every one)
`settings_appearance`'s tests and `mc_appearance`'s are **unedited**. These other tests changed, each keeping its old intent:
- `account_wiring:routes_test`:
  - "T-0063-AC3 /settings/appearance builds the appearance flow, with home below it" (renamed, now also `T-0070-AC3`): the route stack is now home, settings, appearance, so after the first Back the index shows, and a second Back goes home. The old assertion (home is below) still holds one Back further.
  - The drift test (renamed, now also `T-0070-AC3`): the route-set assertion lists `/settings`, the relative `appearance` and `/auth/sign-in` (names `settings_home`, `settings_appearance`, `auth_sign_in`); `AppLocations.settingsAppearance` still equals `SettingsAppearanceRoute().location`.
  - The `_Targets` stand-in has `settingsHome()`; the initializer test also builds the index flow.
- `mini_client:settings_route_test`:
  - Four tests that went home, Settings, then picked a theme now go through the Appearance row (`openAppearance` helper); the first of them is the next item.
  - "home's Settings entry opens the appearance …": Back goes to the index (subtitle `Dark`), then home.
  - The cold link test: Back goes to the index, then home.
  - Its config literal has `"version":"0.1.0"`.
- `mini_client:analytics_screens_test`: the expected route names include `settings_home`.
- `app_core:sign_in_guard_test`: `/settings` joined the open locations (an addition).
- The e2e journeys `settings_journey_test`, `settings_signed_in_test` and `settings_deeplink_test`: through the Appearance row, and Back twice.
- Additions only: `mc_config:app_config_test` (version), `l10n_check:workspace_gate_test` (the `settings_home` set).

No test was deleted, skipped or weakened, and there is no `// ignore:`.
