# T-0066: `auth_sign_in` feature and the `/me/**` sign-in guard (F045; P-044, P1-16 AC4)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verification | ADR-0015 exception (**auth/security**): `/code-review`, one fix round, then **one narrow Sonnet Verifier** for the guard and sign-in paths only, then the TL merge gates |
| Branch | `fleet/T-0066-auth-sign-in` |
| Created | 2026-11-27 |
| Depends on | T-0039/T-0050 (`mc_session`, `mc_api_auth`, `authPinned`), T-0048 (FW exemplar), T-0045 (`mc_forms`, `mc_ds_forms`), T-0049/T-0054/T-0057 (`AppFlows`, `nestUnderHome`, async-guard pins), T-0058 (`mc_ds_overlays`) |
| Related | plan 01 F045, §4.2 (guards use one `redirect`: signed-out `/me/**`, `/library/**`, `/store/checkout` → `/auth/sign-in?from=<uri>`), P1-16 AC4; F-0048, F-0049 (notes 10 and 11), F-0050; P-044, P-110, P-114 |

## Goal
Replace the temporary fixture sign-in sheet (P-044) with a real sign-in feature, and add the router guard the plan calls for. A signed-out user who opens a protected link signs in first and then lands where they were going. Features that call `requestSignIn()` get the same screen.

## Scope
- **In: `feature/auth/auth_sign_in`, FW-style. Copy `library_reading_list_editor`'s shapes.**
  - **Flow and navigator.**
    - `AuthSignInFlow` has one form page with email and password, built on `mc_forms` and `mc_ds_forms`.
    - It has a "Use a demo account" helper listing the fixture users, which fills the form.
    - It completes with a result `SignInResult` (`signedIn` or `cancelled`) through the flow-result pattern (`FlowResultRoute`/`AppFlows`).
    - `AuthSignInNavigator` has no outbound methods yet. Sign-up is out of scope.
  - **Sign-in.**
    - Sign-in goes through `mc_api_auth`/`mc_session` (`POST /v1/auth/sign-in`).
    - Errors map to fields or a banner. Wrong credentials are a typed code from `mc_fixtures_identity`. Add a credential check there if the fixture doesn't have one yet, with tests.
    - The scenarios `identity.expired_token` and `server_error` must be handled.
    - A double submit sends one request.
  - **Copy and tests.** l10n en and de. BDD with AC tags, contract tests, and unit tests for pure logic allowed. **No goldens** (ADR-0015).
- **In: `app/wiring/account_wiring`, `app_core` and `mini_client`.**
  - **Route.** `/auth/sign-in?from=<uri>` as a result route (`AppFlows.signIn(router, {from})`), plus `AppLocations.signIn(from)` and its drift test.
  - **Guard.** The router `redirect` (the existing placeholder at `app_router.dart`) sends a signed-out user on `/me/**`, `/library/**` or `/store/checkout` to `/auth/sign-in?from=<original>`.
    - After `signedIn`, the app goes to `from` (`go(from)`).
    - On `cancelled`, it goes home, or back if there is a back stack.
    - An already signed-in user is never redirected.
    - A `from` must be an in-app location (`miniclient://app/…` or a path). Anything else falls back to home, so there is no open redirect.
    - The guard re-evaluates on session changes (`refreshListenable`), so signing out on a protected screen redirects. P-110's pins exist for this.
  - **`requestSignIn()` uses the new route.** Replace `requestFixtureSignIn`, the sheet, with `AppFlows.signIn` in every wiring that has it: publishing (favourite), library (reading lists), commerce (cart), chronicle (trivia results) and account (settings sync).
    - It returns `true` only when a session now exists.
    - Delete the fixture sheet and its keys once nothing uses them. List the tests that moved, and keep their assertions.
  - **Editor result after a guard (F-0049 note 11).** Decide and document how home learns a reading list's result after a guard's `go(from)`. Suggested: home reloads lists on a `DataChanged('library')` event, or on returning to home. Keep it small.
  - **Home.** Add a Sign in / Sign out entry. It is useful for e2e and for trying the app.
- **Out:** sign-up, password reset, social login, biometrics.

## Acceptance criteria
- **T-0066-AC1:** Sign-in.
  - With a fixture user's credentials, I'm signed in and the flow completes `signedIn`.
  - Wrong credentials show a typed error on the form, and nothing is signed in.
  - `server_error` shows an error with retry.
  - A double tap on Submit sends exactly one request.
  - BDD tests in German and `en_XA` show no overflow at 2×.
- **T-0066-AC2:** The guard.
  - Signed out, a cold link to `/me/lists/new`, a running link to it, and pushes onto `/library/**` and `/store/checkout` all land on sign-in with `from` set.
  - After signing in, the app shows the original target with a back stack to home. Cancel ends at home.
  - Signed in, there is no redirect.
  - A foreign `from` falls back to home.
  - Signing out on `/me/lists/l-1/edit` redirects to sign-in.
  - Every case completes its `AppFlows` caller exactly once (the P-110 pins stay green).
- **T-0066-AC3:** Callers.
  - The favourite, reading lists, cart, trivia results and settings sync each open the new sign-in.
  - Each returns `true` only after a real sign-in and `false` on cancel.
  - The previous sign-in BDD scenarios of those features pass with the step updated, with no assertion removed.
- **T-0066-AC4:** E2E on your own simulator.
  - home → Sign in (demo user) → favourite a comic → sign out → the cold link `miniclient://app/me/lists/new` → sign in → the editor → Back → home.
  - Take screenshots.
- **T-0066-AC5:** Gates.
  - `test --lockfile_mode=error //...`, lint, `mc_arch_check`, `rules_fork.sh check`, the format gate, `l10n_check`, and `T-0042-AC4_safety.sh` after `tool/ide_sync`.
  - The 50-run flake check on new and changed targets that touch the session, storage or races.
  - Every cited test exists.

## Log
- 2026-11-27: Created and dispatched (TL). PO hybrid choice: a hand-built feature in parallel with the generator. It closes P-044 and the deferred auth guard.
