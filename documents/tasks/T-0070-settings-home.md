# T-0070: `settings_home`, the settings index with a `/settings` parent route (F055)

| Field | Value |
|---|---|
| Status | In Progress |
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
