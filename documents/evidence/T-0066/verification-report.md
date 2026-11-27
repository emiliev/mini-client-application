# T-0066 narrow auth verification (Verifier): PASS

Base: `9c96f743`. Scope: ADR-0015 item 4 exception (auth/security). No defects found that block the merge; two low observations below.

## 1. Open redirect: PASS
- `verifier/probe_from_test.dart.txt`: 75 hostile `from` values through `safeSignInTarget` (about 70 not in the engineer's table): `https:`, `https:evil.com`, `JaVaScRiPt:`, `data:`, `file:`, `tel:`, leading/trailing space, tab/newline inside, `\\evil`, `/\evil`, `////evil`, `%2f%2f`, `%5c`, double, triple, quadruple and quintuple encodings, `miniclient://evil`, `miniclient:/me`, `miniclient://APP@evil`, `miniclient://app:80`, `miniclient://app//evil`, `MINICLIENT://`, NBSP, zero-width, U+2028, empty, whitespace, `/auth/sign-in` in 9 spellings (trailing slash, `.`, `%2e`, `%2F`, `%252F`, `..`, `miniclient://app/auth/sign-in`). All landed at `/` (home). Properties asserted: no scheme or authority, no `//` or `\` at any decode level.
- The same values (12 of them) through the real router in `verifier/probe_guard_app_test.dart.txt`, signed out (sign in, end at home) and signed in (redirect, no loop, end at home).
- Observation (low, not exploitable): `/AUTH/sign-in` and `/auth//sign-in` pass through as targets. go_router matches case-sensitively and does not match them as the sign-in page, so they end on not-found or, if matched, redirect a signed-in user to home. No loop found.

## 2. Guard: PASS (real router, real form)
- Signed out cold and running links to `/me`, `/me/lists/new?x=1`, `/me/lists/l-1/edit`, `/me/anything/else`, `/library`, `/library/a/b`, `/store/checkout`, `/ME/...`, `/%6De/...`, `/x/../me/...` all reach `/auth/sign-in?from=...` (normalised path and query kept). A push of `/me/lists/new` also does. Not now goes home with `canPop` false.
- Sign-in lands on the editor (`/me/lists/l-1/edit`) with home beneath it.
- Sign-out with the protected page under 1 and under 2 open pages (`/settings/appearance`): sign-in with `from` = the editor. Back from sign-in is home, `canPop` false, no editor reachable. Signing in again returns to the editor, pop goes home.
- Signed in, `/auth/sign-in?from=/me/lists/new` goes to the editor. A hostile `from` goes home.

## 3. Session safety: PASS
- `verifier/probe_epoch_test.dart.txt` (`AuthApi.signOut(ifEpoch:)`): a stale epoch is a no-op with zero `/v1/auth/sign-out` calls, also after sign-out then sign-in. The current epoch signs out and calls the server once. Signed out already is harmless.
- Bloc review (`auth_signin_bloc.dart` `_submit`): undo only when the form was closed, nobody was signed in before, and the epoch this request created is still current. `bloc_guards_test` covers a user signed in before (B stays) and a newer session elsewhere (stays).
- Favourite: `comic_favourite_bloc.dart` is unchanged by the branch. It reads `_session.epoch` after `requestSignIn()` and passes `authPinned(epoch)` to `putFavourite`/`deleteFavourite` (`comics_details_repository.dart:49-52`).
- Observation (low): if a different user signs in elsewhere mid-request, while the form's `signedInBefore` was false, and this request then lands and the form is closed, this request replaces that session, then undoes itself: the user ends signed out. Replacement of an elsewhere session is inherent to a sign-in landing; a sign-in elsewhere during an open sign-in form is not reachable from the current UI.

## 4. Callers: PASS
`requestAppSignIn` returns `signedIn && session.isSignedIn`. `publishing_wiring:routes_test` (4 hits) and `library_wiring:routes_test` (3 hits) `T-0066-AC3` run green. `grep -rn requestFixtureSignIn|fixture_sign_in_sheet|FixtureSignIn` outside `documents/`: no match.

## 5. Gates: PASS
- `test --lockfile_mode=error //...` on `9c96f743`: 236 of 236 pass.
- 20 runs, `--nocache_test_results`, all pass: `app_core:sign_in_guard_test`, `sign_in_guard_router_test`, `mini_client:sign_in_guard_app_test`, `auth_signin:bloc_guards_test`, `contract_test`, `account_wiring:routes_test`, `publishing_wiring:routes_test`, `library_wiring:routes_test`.

Probes were added to the BUILD files only for the run and removed afterwards. They are kept here as `.dart.txt`.
