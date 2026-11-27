# T-0066: `auth_sign_in` feature and the `/me/**` sign-in guard (F045; P-044, P1-16 AC4)

| Field | Value |
|---|---|
| Status | Handed off (Engineer), awaiting review |
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
- 2026-11-27: Engineer built `feature/auth/auth_signin`, the guard, the sign-in route, `requestAppSignIn`, home's Sign in / Sign out, moved the callers' tests, and ran gates, 50-run flake and e2e (own simulator, deleted). Details: [F-0066](../findings/F-0066-sign-in-and-guard.md).

## Outcome
**Deviations from the brief (all in F-0066):**
- The package is `auth_signin`, not `auth_sign_in`: `gen_l10n` reads `in_en` from `auth_sign_in_en.arb` as locale `id_EN` and fails; `l10n_check` requires `<package>_<locale>.arb`. `mcgen` needs a name check.
- The sign-in route's result is a `bool`, not a string: a guarded push hands the sign-in page's pop value to the original caller, so a string arrived as a list id.
- The guard ticks `refreshListenable` on sign-out only (a refresh at sign-in restores a stale stack and brings the page back), and `SignInGuard.bind(router)` handles pushed pages, which a refresh does not re-evaluate.
- `requestFixtureSignIn` became `requestAppSignIn(routerRef, session, purpose)`; the `reason` text became a closed `SignInPurpose` code, so a link cannot put words on the screen.
- Leaving the form mid-request undoes a sign-in that lands (answer false means no session).
- **Editor result after `go(from)`:** home learns of it from the `DataChanged('readingLists')` the editor already announces, and shows "Reading lists changed" (no id). A real home reloads its lists on that event.

**Changed callers:** `comics_details` (publishing_wiring), `library_reading_list_editor` (library_wiring), `store_home` (commerce_wiring), `trivia_quiz` (chronicle_wiring), `settings_appearance` (account_wiring): each navigator calls `requestAppSignIn` with its purpose and no longer takes `AuthApi`. Deleted: `fixture_sign_in_sheet.dart`, `sign_in_sheet_test.dart`. T-0067 had landed on `origin/main` by hand-off: merged here, its `universe_wiring` navigator (`characters_details`) now uses `requestAppSignIn(purpose: favourites)`, and its `universe_wiring` and `analytics_screens_test` sign-in tests moved to the stand-in and the real form (assertions kept). Merge result: `test --lockfile_mode=error //...` 236/236, lint, arch, l10n, format, `rules_fork` green.

**Tests that moved (assertions kept, step changed from the sheet to the sign-in screen):** the five wirings' `requestSignIn` tests (`T-0041-AC6`, `T-0048-AC6`, `T-0056-AC3`, `T-0064-AC3`, `T-0063-AC3`, now also named `T-0066-AC3`); `reading_list_route_test`, `deep_link_back_stack_test`, and the e2e journeys `reading_list_journey`, `reading_list_deeplink`, `comics_journey`, `settings_signed_in`. Sheet-only tests (barrier, drag, Back refused while busy, "sheet closed answers the real outcome", "failed sign-in keeps the sheet") have no counterpart: their behaviour is the feature's (BDD "server error", bloc guards: no Not now mid-request, undo on leave, and the `account_wiring` Back-mid-request test). Test edits to existing tests beyond that: `app_test` scrolls to "Open placeholder 7" (home grew); `buildAppRouter` callers in `app_test`, `not_found_test`, `deep_link_back_stack_test` pass a stub session; `analytics_screens_test` lists `auth_sign_in`. No test deleted-without-replacement beyond the sheet ones above, none skipped, no `// ignore:` kept.

| AC | Evidence |
|---|---|
| T-0066-AC1 | `auth_signin:bdd_test` (`auth_signin_sign_in.feature`: sign-in, trimmed email, wrong credentials x2, correction, server error and retry, `identity.server_error`, `identity.expired_token`, double tap sends 1 request, empty and invalid form, demo accounts, Not now, reasons; `auth_signin_l10n.feature`: German, `en_XA` at 1x and 2x), `contract_test`, `bloc_guards_test`, `unit_test`, `flow_scope_test`, `architecture_test`, `account_wiring:routes_test` (real route and reasons) |
| T-0066-AC2 | `app_core:sign_in_guard_test` (protected table, redirects, the open-redirect table), `app_core:sign_in_guard_router_test` (cold, running, push, `/library`, `/store/checkout`, Not now, signed in, foreign `from`, sign-out redirect, refresh behaviour, each `AppFlows` caller once), `account_wiring:routes_test` (real route, 4 hostile `from`s), `mini_client:sign_in_guard_app_test` (real router, sign-out on a pushed editor) |
| T-0066-AC3 | the five wirings' `routes_test` (`T-0066-AC3`: opens the screen with its reason, true only after a real sign-in, false on Not now, true at once when signed in), `sign_in_guard_router_test` (`requestAppSignIn`) |
| T-0066-AC4 | `integration_test/auth_signin_journey_test.dart`, PASS on `mc-T-0066-engineer-45844` (deleted), screenshots 70 to 77 in `documents/evidence/T-0066/engineer/` (`e2e-summary.md`); the four moved journeys PASS too |
| T-0066-AC5 | `gate_*.log` in the evidence dir: `test --lockfile_mode=error //...` 231/231, lint, `mc_arch_check`, `rules_fork.sh check`, format gate, `l10n_check`, `T-0042-AC4_safety.sh` PASS; `gate_flake50.log`: 50 runs, 0 failures, `--nocache_test_results`, on `bloc_guards_test`, `contract_test`, `bdd_test`, `sign_in_guard_test`, `sign_in_guard_router_test`, `account_wiring:routes_test`, `sign_in_guard_app_test` |

**Not done:** see F-0066 "Not done" (protected page below a non-protected top; signed-in user on `/auth/sign-in`). Not run: the full e2e suite (only the five touched targets).

**Review round (one fix round):** (1) the sign-out guard walks every page of the stack and goes to sign-in with `from` = the topmost protected page; (2) a mid-request leave undoes only the session this request created (`AuthApi.signOut(ifEpoch:)`) and keeps the new session when someone was signed in before (B, never signed out); a signed-in user at `/auth/sign-in` is redirected to `safeSignInTarget(from)`; (3) a system back or an iOS swipe is refused while a request runs (`PopScope` plus a pop entry on the flow's outer route), tested on Android and iOS. Nits: comment fixed, `go(from)` stack drop documented in F-0066. Tests: `sign_in_guard_router_test`, `sign_in_guard_test`, `auth_signin:bloc_guards_test`, `account_wiring:routes_test`. The first round's Back-mid-request test became the link-replaces-form test, because a back is now refused.
