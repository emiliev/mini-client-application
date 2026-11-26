# T-0048: `library_reading_list_editor` exemplar (FW archetype), P1-20

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (**Opus**: first FW exemplar, which the bricks copy; ADR-0011) |
| Verifier | crew: Verifier, **Opus tier** (exemplar; auth-gated writes) |
| Branch | `fleet/T-0048-reading-list-editor` |
| Created | 2026-11-26 |
| Depends on | T-0039 (session, `mc_api_auth`), T-0041 (SC exemplar: auth-gated writes, epoch checks), T-0045 (`mc_forms` + `mc_ds_forms`), T-0047 (`mc_fixtures_library`), T-0043/T-0038 (comic picker data) |
| Related | plan 01 F066, P1-20 (EX-AC1–6), §3.3, §4.3 (flow results); ADR-0007, ADR-0010, ADR-0011; R4, R6, R15–R17, R30; F-0038, F-0040, F-0045 |

## Goal
The fourth exemplar, form/wizard (FW): `feature/library/library_reading_list_editor`. It creates a reading list in a three-step wizard, or edits an existing one:
1. Details: name, description, and visibility as `McSegmented`.
2. Pick comics: search and toggle, using `McSearchField` and `McChipGroup` or a list.
3. Order and review: reorder the picked comics, then confirm.

On submit, the flow completes with the new or updated list id, and **the wiring returns that result to the caller**. That is the plan's flow-result pattern (§4.3), so this is its first real use. The bricks copy this package's shape for every FW feature.

## Scope
- **In:**
  - **`feature/library/library_reading_list_editor`:**
    - `ReadingListEditorFlow`, with args `{ListId? editing}` and the result `ListId`.
    - `ReadingListEditorNavigator`, with `requestSignIn() → Future<bool>`.
    - A retrofit API for `v1/me/lists*` and `v1/comics` (the picker search).
    - A stateless repository.
    - A wizard built on `mc_forms`'s `WizardController` and the `mc_ds_forms` widgets, with the blocked-Next reveal (T-0045).
    - Validation through `mc_forms` validators that match the backend's rules (name 1–60 characters, description ≤ 280, 1–100 comics). Server-side 400s map back to the right step and field.
    - Edit mode loads the list and pre-fills every step.
    - Signed out: entering the flow awaits `requestSignIn()`; on false, the flow closes with no result.
    - l10n in en and de.
    - BDD, contract tests and goldens. No solitary unit tests (R6).
  - **`app/wiring/library_wiring`:**
    - Routes `/me/lists/new` and `/me/lists/:id/edit`.
    - The navigator implementation, reusing the temporary sign-in sheet pattern from `publishing_wiring`. Factor it into `app_core` if two wirings now need it.
    - **The flow result handed back to the caller.** For example, a `Future<ListId?> createReadingList()` entry the app can await, or a typed `pop` result through go_router's `push<T>`. Document the pattern for the bricks.
  - **mini_client:**
    - A "New reading list" entry on home, or under a Library placeholder, that awaits the result and shows "List created" with the id.
    - The deep link `miniclient://app/me/lists/new`.
    - The library mock domain in `appMockDomains`.
- **Out:** a list detail or browse feature (only the editor), drag-and-drop polish beyond reorder handles, and collaborative lists.

## Acceptance criteria
- **T-0048-AC1 (EX-AC1):** Given `library.default` and signed in as `u-100`, when I complete the 3 steps with a valid name and 3 comics, then a POST is sent with exactly those values in the chosen order, and the flow completes with the new list id. BDD.
- **T-0048-AC2 (EX-AC2):**
  - Given a `server_error` on submit, then an inline error shows on the review step with Retry. Retry resends once, and nothing is lost.
  - Given a 400 `invalid_name` from the server, then the wizard goes back to step 1 and shows the error under the name field.
  - BDD.
- **T-0048-AC3 (EX-AC3):** Edit mode loads list `l-1`, pre-fills all steps and sends a `PUT` for details and a `PUT …/items` for the order, only for parts that changed. A no-change submit sends nothing and completes with the same id. A list owned by another user shows the not-found state.
- **T-0048-AC4 (EX-AC4):** Given locale `de`, the step titles, labels, validation messages and buttons are German. Given `en_XA`, nothing overflows on any step at 1× and 2×.
- **T-0048-AC5 (EX-AC5):** The mini_client e2e covers:
  - home → New reading list;
  - an invalid step 1, where tapping Next shows the error;
  - fixing it and moving on through the steps;
  - submit, then home shows "List created" with the id;
  - the deep link.

  Screenshots of each step are required.
- **T-0048-AC6 (P1-20 AC6):**
  - Given an invalid step, Next is disabled and a tap on it shows the error (`onBlockedNext`).
  - When the wizard is submitted, the flow completes with the new list id, and **the wiring returns it to the caller**: the app-level test awaits the result.
  - A double submit sends one POST.
  - A session change during submit (sign-out or user switch) writes nothing for the wrong user (the epoch check, F-0040).
  - Going back keeps every step's values.
- **T-0048-AC7 (architecture and codegen):**
  - `mc_arch_check` passes.
  - The barrel exports only the flow, the navigator, and the arg and result types.
  - Generated code: nothing committed, byte-identical to build_runner, and the cutoff check passes.
  - The fixtures check passes.
  - `MC_GENERATED_DART` is used in every glob, and `T-0042-AC4_safety.sh` passes after `ide_sync`.
- **T-0048-AC8 (gates):** coverage ≥ 90 %; `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format and `l10n_check` pass; every check traces to a `T-0048-ACn`.

## Log
- 2026-11-26: Created (TL); dispatched after T-0047 merged.
- 2026-11-27 (Engineer): Branched from `origin/main` `e866b71`; merged `origin/main` `fab18f0` before handoff (docs only, no conflict; T-0046 is not on `main` yet, so its `app_core`, `mini_client`, `mc_test_steps` and `l10n_check` changes are still to be met). Every generator built on the first try, including a flow-scoped `@lazySingleton` bloc with `@disposeMethod`: **no codegen shim failed on a real-world case**, so no R28 fallback. Two kit gaps are handled with the kits' public API and need a TL decision (F-0048 facts 3 and 4). Handed off; evidence in `documents/evidence/T-0048/engineer/`.

- 2026-11-27 (Engineer): Review round (TL decisions 1 to 4, findings 5 to 11, one round). Merged `origin/main` `1d9bde1` (docs only; T-0046 is still not on `main`, so its `app_core`, `mini_client`, `mc_test_steps` and `l10n_check` changes are still to be met). Locks unchanged. Re-handed off; see "Review round" below.

## Outcome
**Handed off** for review and verification on `fleet/T-0048-reading-list-editor`. Finding: [F-0048](../findings/F-0048-form-wizard-exemplar-and-flow-results.md). Evidence: [`documents/evidence/T-0048/engineer/`](../evidence/T-0048/engineer/).

### What was built
- **`feature/library/library_reading_list_editor`** (FW), in plan 01 §3.3's layout and comics_details' shapes:
  - **Barrel:** `ReadingListEditorFlow`, `ReadingListEditorNavigator`, `ReadingListId` (the argument in edit mode and the result; an extension type on `String`). R4.
  - **Navigator:** `Future<bool> requestSignIn()`. The result does not go through the navigator.
  - **Flow:** `ReadingListEditorFlow(navigator:, onComplete:, editing:)`, keyed by `editing`. Flow state `{editing, step}`; **one flow page per step** (`details`, `comics`, `review`), so the iOS back swipe and the app bar's back on steps 2 and 3 go one step back inside the flow. `onComplete` gets the saved list's id once, or null when the flow ends without saving (a declined sign-in, Close after the session changed).
  - **Data:** one retrofit `ReadingListEditorApi` (relative paths): `GET v1/me/lists/{id}`, `POST v1/me/lists`, `PUT v1/me/lists/{id}`, `PUT v1/me/lists/{id}/items`, `GET v1/comics` (the picker search). Eight DTOs, all `@Freezed(fromJson: true, toJson: true)` (R30). Domain `ReadingList`, `ReadingListDraft` (change detection against what the backend holds), `PickedComic`, `ReadingListVisibility`. Stateless `@injectable` repository; a `400` that names a field becomes `SaveRejected(field, code)`, read from the error body.
  - **Blocs (2):** `ReadingListEditorBloc` is a `@lazySingleton` of the flow's own container (with `@disposeMethod`), shared by the three step pages through `BlocProvider.value`, because the wizard's values must outlive the pages (F-0048 fact 2). It owns `mc_forms`' `WizardController` (one form over all steps; name 1 to 60 characters trimmed, description at most 280, 1 to 100 comics), the sign-in gate, the edit load, the save (create, or `PUT` details and `PUT .../items` only for what changed; nothing for no change), the session epoch check after every await and between two writes, and the backend's verdicts (`ServerVerdicts`). `ComicPickerBloc` is per page: a debounced search (`DebouncedQuery`) where only the latest answer counts.
  - **Pages:** step 1 (`McFieldGroup`, two `McFormTextField`s, `McSegmented`; it also shows signing in, loading, not found, a failed load with Retry, and the ended session with Close), step 2 (`McSearchField`, `McChipGroup.multi` of the picks, the result rows), step 3 (summary, reading order with drag handles and up/down arrows, the inline save error with Retry; `PopScope` while saving). `McAppBar(leading: const McFlowBackButton())` on each; `McWizardStepper.fromState` with `onBlockedNext` → `touchCurrentStep` (T-0045), bound only on the current step's page.
  - **DI:** `ReadingListEditorDIInitializer`; root imports `[Dio, EventBus, Monitoring, SessionReader]`, hand-written and pinned by `flow_scope_test`.
  - **l10n:** en, de and `en_XA` (47 keys). The ARB files are named for the package (`library_reading_list_editor_<locale>.arb`, as `l10n_check` requires).
  - **Tests (R6):** 4 `.feature` files (36 scenarios, 41 tests with the outlines' examples), `contract_test`, `flow_scope_test`, `golden_test` (7 goldens), `architecture_test`.
- **`app/wiring/library_wiring`** (was a skeleton), shaped as publishing_wiring: `reading_lists_routes.dart` (`NewReadingListRoute` `/me/lists/new`, `EditReadingListRoute` `/me/lists/:id/edit`), each built in a `FlowResultRoute`; `LibraryRouteTargets` + impl (maps `ReadingListId` to the app-level `String`); `ReadingListEditorNavigatorImpl` (`@LazySingleton`, the shared fixture sign-in); `LibraryNavigatorsDIInitializer`, `LibraryWiringDIInitializer`; `routes_test` (8 tests).
- **`app/wiring/app_core`:**
  - **The flow-result pattern** (`src/router/flow_results.dart`): `FlowResultRoute<T>` and `completeRoute` (pops its own route with the result, only while it is on top; a route with nothing below it, a deep link, goes home), and `AppFlows.createReadingList` / `editReadingList` (typed `push<String>`). Documented there and in F-0048 fact 1 for the bricks.
  - `AppLocations.newReadingList`, `editReadingList(id)`; `LibraryMockDomain` in `appMockDomains`.
  - **The fixture sign-in sheet moved here from publishing_wiring** (two wirings need it now): `requestFixtureSignIn(routerRef:, session:, auth:, reason:)` and the sheet, unchanged in behaviour, with a `reason` line; keys `app.sign_in.*`.
  - Tests: `flow_results_test` (7), `sign_in_sheet_test` (8, the T-0041 sheet pins ported to the shared function), `app_layer_test` (7, closing the package's coverage gap).
- **`app/wiring/publishing_wiring`:** `ComicsDetailsNavigatorImpl.requestSignIn` calls `requestFixtureSignIn(reason: 'to keep your favourites')`; its own sheet file and the key exports are gone; `mc_fixtures_identity`, `mc_ds_buttons` and `mc_ds_layout` left its runtime deps. `routes_test` unchanged and green.
- **`app/mini_client`:** home has "New reading list" (awaits `AppFlows.createReadingList` and shows "List created: <id>", then "Edit list <id>" → "List saved: <id>"); `test/reading_list_route_test.dart` (4: the app awaits the result through the real editor, edit, Back gives nothing, the deep link); e2e `reading_list_journey_test.dart` and `reading_list_deeplink_test.dart`; `comics_journey_test.dart` follows the moved sheet keys.
- **`mc_test_steps` (generic):** `the backend received {route} with the body` (a data table of JSON fragments), `the backend received {route} with a token of {user}` (for session switches), `the text scale is {n}`.

### AC → evidence
JUnit names carry the IDs ([test_names.txt](../evidence/T-0048/engineer/test_names.txt): 100 names, AC1 13, AC2 8, AC3 19, AC4 7, AC5 5, AC6 38, AC7 8, AC8 6).

| AC | Tests and evidence |
|---|---|
| AC1 | `:bdd_test` create: "Three steps create a list with the comics in the chosen order" (the POST body, exactly those values in the reordered order, the bearer, `201`, the editor completes with `l-5`, the stored list, one `DataChanged('readingLists')`); trimmed name, private by default, a pick dropped again; the rules as a Scenario Outline (blank, 61, 281) and 60 trimmed; the search (empty, failure, Retry). Edit: "A list holds at most 100 comics". `:contract_test` create; `:flow_scope_test` the accessible result row; goldens step 1, step 2 |
| AC2 | `:bdd_test` "A failed save shows an inline error with Retry, and Retry resends once with nothing lost" (1 then 2 POSTs, same body), "A name the backend refuses takes the wizard back to step 1 with the error under the name" (31 flags: 31 characters to the form, 62 runes to the backend), the same for the description, the partial edit failure, a failed load with Retry. `:contract_test` every `400` mapping (name, description, duplicate, too many; and the bodies that are ordinary failures). Golden: the failed save |
| AC3 | `:bdd_test` edit: pre-fill of all three steps, no-change save sends nothing and completes with `l-1` (no announcement), name only → one `PUT` details, order only → one `PUT .../items`, both in order, Retry after a partial failure sends only the items; `l-4` (another user's) and `l-999` not found. `:flow_scope_test` a different list builds a new flow. `library_wiring:routes_test` the edit route; `mini_client:reading_list_route_test` edit from home. Goldens: review, not found |
| AC4 | `:bdd_test` l10n: German steps, labels, validation messages, buttons and errors (create and edit, not found, the ended session); `en_XA` at 1x and 2x through every step and every state outside the wizard, `nothing overflows`. `//tool/l10n_check:workspace_gate_test` "T-0048-AC8 the gate checks the library_reading_list_editor ARB set" |
| AC5 | e2e on a fresh `mc-T-0048-engineer-*` (iOS 26.2, deleted): `reading_list_journey_test` 30–36 (home → New reading list → sign-in sheet → blocked step 1 with the error → fixed → step 2 with a blocked Next → picks → reorder → Create list → home "List created: l-5"), `reading_list_deeplink_test` 37 (`miniclient://app/me/lists/new`) and 38 (a link to edit `l-1` sent to the running app), and the T-0041 and T-0033 journeys re-run: [e2e-summary](../evidence/T-0048/engineer/mini_client/e2e-summary.md), 4 of 4 PASS. `mini_client:reading_list_route_test` the deep link; `library_wiring:routes_test` the deep link goes home when finished; `app_core:flow_results_test` the locations |
| AC6 | Blocked Next: `:bdd_test` "An invalid step keeps Next disabled, and a tap on it shows why" (steps 1 and 2). **The result reaches the caller:** `mini_client:reading_list_route_test` "home awaits the editor and shows the list id the wiring returned" (the real flow in the real app), `library_wiring:routes_test` "the wiring returns the new list id to the caller that awaits AppFlows.createReadingList", `app_core:flow_results_test` (result, null, Back, a dialog above, a deep link, a late call). **Races, held and released:** double Create → 1 POST, double Save → one write of each part; while saving the buttons are off and a back swipe is refused; going back by the button and by the swipe keeps every value; going back while a search is held; a slow older search answer; a user switch during the save (the POST left with reader's token, nothing handed out, collector unchanged), a sign-out during the save, a sign-out before Finish (0 POST), a user switch between the two writes of an edit (0 `PUT .../items`), a session change during the load; `:flow_scope_test` an editor closed while its save is held. Sign-in gate: signed out the editor asks first; a declined sign-in ends with no result. The shared sheet: `app_core:sign_in_sheet_test`, `library_wiring:routes_test`, `publishing_wiring:routes_test` |
| AC7 | `:architecture_test` (barrel exactly `ReadingListEditorFlow`, `ReadingListEditorNavigator`, `ReadingListId` with `show`; every generator-read file is Flutter-free); `mc_arch_check` OK; `:flow_scope_test` (resolve everything; a root without `SessionReader` fails naming it; `McAppBar` + `McFlowBackButton` on every step); `:contract_test` (served JSON round-trips byte for byte). [byte identity 12 of 12 EQUAL](../evidence/T-0048/engineer/T-0048-AC7_matches_build_runner.md); [cutoff](../evidence/T-0048/engineer/T-0048-AC7_cutoff.md); [not committed](../evidence/T-0048/engineer/T-0048-AC7_generated_not_committed.md); [gen-l10n parity](../evidence/T-0048/engineer/T-0048-AC7_gen_l10n_parity.md); fixtures check in the gates. `MC_GENERATED_DART` in the feature's, library_wiring's and app_core's globs; after `tool/ide_sync --env dev` (46 files), [`T-0042-AC4_safety.sh`](../evidence/T-0048/engineer/T-0042-AC4_safety.md) **PASS** (the synced tree ran 0 actions and 0 of 137 tests; 47,604 outputs byte-identical; every negative control fired); `tool/ide_sync --clean` removed 82 files |
| AC8 | [`T-0048-AC8_gates.md`](../evidence/T-0048/engineer/T-0048-AC8_gates.md), below |

### Gates (AC8)
[`T-0048-AC8_gates.sh`](../../tool/checks/T-0048-AC8_gates.sh) → **PASS**, one run on the merged tree: `test //...` **137/137** (the feature, `//app/...`, `mc_test_steps` and `l10n_check` uncached first), `build --config=lint //...`, `mc_arch_check` OK, `rules_fork.sh check`, `dart format` 0 changed, `l10n_check` OK, fixtures check, relative API paths, the four AC7 checks. **Coverage:** library_reading_list_editor 768/788 = 97.5 %, library_wiring 37/37 = 100 %, app_core 339/353 = 96.0 % (88.1 % on the first run: `route_probe`, `stub_page`, `app_media` and two locations had no test in app_core itself, a pre-existing gap now closed by `app_layer_test`), publishing_wiring 47/47 = 100 %. `pubspec.lock` and `MODULE.bazel.lock` unchanged.

The e2e ran at `9c5431b`. The commits after it only add the result row's semantic tap action, tests and evidence, and merge `origin/main` (docs only), so it was not re-run.

### Mutations
[mutations.sh](../evidence/T-0048/engineer/mutations.sh) (`MC_TASK=T-0048 MC_ROLE=engineer`): **47 of 47 killed by a failing test**, none by a compile error ([log](../evidence/T-0048/engineer/mutations.log)). Every AC has some, and each AC6 race has its own: double submit (AC6-h), a user switch during the save (AC6-i), between two writes (AC6-j), a sign-out before Finish (AC6-k), during the load (AC6-l), a closed editor (AC6-m), going back (AC6-n, AC6-o, AC6-p). In the first full run, AC2-e only broke the build (type promotion); it was rewritten.

### Goldens
New: 7 in `test/golden/goldens/` (steps 1 to 3, the blocked step 1, a failed save, not found, the ended session), all looked at. No existing golden changed.

### Edits outside the named areas (TL, please confirm)
- Root `pubspec.yaml`: the new workspace member. `pubspec.lock` and `MODULE.bazel.lock` unchanged.
- `tool/l10n_check` (the gate's data and one test), as T-0032 and T-0041 did.
- `tool/checks/`: new `T-0048-AC7_*` and `T-0048-AC8_gates.sh`.
- `app/mini_client/integration_test/comics_journey_test.dart`: the sheet keys moved (`publishing.sign_in.*` → `app.sign_in.*`).

### Test integrity
No test deleted, skipped or weakened; no `// ignore:`. publishing_wiring's sign-in tests are unchanged (the sheet's behaviour is now also pinned on the shared function in `app_core:sign_in_sheet_test`). Changed: the comics e2e journey's two key constants.

### Decisions for the TL (all answered in the review round, below)
1. **Server-side field errors (F-0048 fact 3):** keep the feature-level `ServerVerdicts` plus the `_rejection` side channel, or add a kit API (`WizardController.reject(Map<String, FieldError>)` and the error body on `ApiClientError`) in a small task before the FW bricks.
2. **Graphemes and runes (F-0048 fact 4):** align `mc_forms` and the library contract, or keep the realistic disagreement (the AC2 scenarios rely on it).
3. **The sign-in sheet in `app_core`** (factored out as the brief allowed), with keys renamed to `app.sign_in.*`.
4. **A session change ends the editing** ("You are no longer signed in as before", Close ends it with no result) rather than closing the editor at once or re-asking for a sign-in; a list created for the old user stays theirs and is not handed to the caller.

### Follow-ups (for `pending-work.md`)
- `app/sandbox/library_sandbox` (P1-20 lists it; not in this task's scope), as P-082.
- Kit: `Validators.maxItems`; bound `McSegmented` and choice-list widgets; `McFormTextField.maxLines` (the description is one line).
- A "discard changes?" confirmation when leaving the editor from step 1 with unsaved values.
- Plan 01 §4.3: name `FlowResultRoute` and `AppFlows` in the text.
- `mcgen wire` for `flow_scope.dart` (as T-0032, T-0041).

## Review round (TL decisions 1 to 4, review findings 5 to 11)
Every fix has a `T-0048-ACn` test that fails without it, and a mutation in [mutations.sh](../evidence/T-0048/engineer/mutations.sh) (ids in brackets).

| # | Fix | Tests (fail without the fix) |
|---|---|---|
| 1 | **Kit support for a server-side field error; the side channel is gone.** `mc_api_errors`: `ApiClientError` keeps the error body's `code` and `parameter` (a map or JSON text; null otherwise). `mc_forms`: `FormController.reject(name, FieldError)` (the field shows the error and the form is invalid until the value changes; a failed submit goes back to idle; `reset` forgets it; a failing rule wins; ignored while submitting) and `WizardController.reject(name, error)` (the same, then goes to the field's step; ignored while completing, after completing and after dispose). The feature maps `parameter` to a field (`ReadingListFields.ofParameter`) and calls `wizard.reject`; `ServerVerdicts`, `SaveFailure`/`SaveRejected`, the `_rejection` side channel and the error-body DTOs are removed. `reject` takes a `FieldError` (not a bare code), so `too_many_comics` keeps its limit for the message | `mc_api_errors:api_failure_test` "T-0048-AC2 a 4xx keeps the code and parameter ..." (4); `mc_forms:form_controller_test` (6) and `wizard_controller_test` (3) "T-0048-AC2 ..."; `:contract_test` "a refused write is an ApiClientError naming the code and the field" (4); BDD "A name the backend refuses ..." [AC2-c to AC2-h] |
| 2 | **The library counts what a reader sees** (grapheme clusters, `package:characters`; CONTRACT.md updated), and a server-only rule: **`duplicate_name`** (check 8: a user's list names are unique, case-insensitive after trimming; a renamed list may keep its own; `listId` names the holder). AC2's refusal path is now "you already have a list with this name" (`' weekend reads '` against `Weekend Reads`), and a new scenario shows 60 flags are a valid name on both sides | `mc_fixtures_library:validation_test` "T-0048-AC2 ..." (6: flags and combining accents, duplicate on create, case and trim, another user's name is free, rename, order); BDD "A name the backend refuses ...", "Lengths count what a reader sees, on both sides ..."; `:contract_test` "60 flags are a valid name" [AC2-i, AC2-j] |
| 3 | The shared sign-in sheet in `app_core` and the key rename: approved | — |
| 4 | A session change ends the editing: accepted | — |
| 5 | **No `add` after `close`.** `close()` calls `super.close()` first, so `isClosed` is true at once; after every await (the sign-in, the load, the save) the bloc returns if closed; `add` is guarded in `_open`, `_onWizardState` and the session listener | `:flow_scope_test` "T-0048-AC6 leaving while the list is loading ..." and "... while the app signs the user in ..." (no exception, `monitoring.errors` empty, no request) [AC6-u, AC6-v] |
| 6 | **A half-saved edit is announced:** a save that wrote anything publishes `DataChanged('readingLists')` once, also when it then failed, or the session or the editor ended | BDD races "A half-saved edit is announced: the details saved, the comics failed"; `:flow_scope_test` "an editor closed while its save is held ... announces what it wrote" [AC6-w] |
| 7 | **An empty list can be renamed.** "At least one comic" applies to a new list, and to an edited one only once its comics change | BDD edit "A list without comics can still be renamed" (`l-3`: one `PUT` details, no items), "Removing every comic of a list is not a change the editor saves" [AC3-g] |
| 8 | **A result under an overlay is kept.** `FlowResultRoute` is stateful: a result that arrives while the route is not current waits, and is handed over once the route is current again (its `ModalRoute` dependency brings `didChangeDependencies`; the pop runs after that frame). Nothing above it is popped, a second completion is ignored, a late one after the route left does nothing. `completeRoute` (a function) is gone | `app_core:flow_results_test` "a result that arrives under a dialog is kept, and the caller gets it once the dialog closed", "a second completion pops nothing more", "completing after the route left the tree does nothing" [AC6-t, AC6-f, AC6-e] |
| 9 | Home ignores New and Edit while an editor it opened is open | `mini_client:reading_list_route_test` "T-0048-AC5 a double tap on New reading list opens one editor" [AC5-c] |
| 10 | `_closing` is gone; `_canWrite` uses `isClosed` (see 5), with the comment corrected | [AC6-m] |
| 11 | Follow-ups to the TL for `pending-work.md`: `library_sandbox`, `Validators.maxItems`, bound segmented and choice widgets, multi-line `McFormTextField`, a discard-changes prompt, plan 01 §4.3 | — |

**Also:** the name's server error reads "You already have a list with this name. Please choose another." (en, de, `en_XA`); `mc_api_errors` was not under a coverage gate before and was at 85 % with its older branches (cancel, bad certificate, an unknown inner error, a status below 400, a raw `FormatException`), so `api_failure_test` gains "T-0048-AC8 the other Dio outcomes" (4); [F-0048](../findings/F-0048-form-wizard-exemplar-and-flow-results.md) facts 1, 3, 4 and 5 follow the decisions.

**Removed or changed tests (disclosed):**
- Removed: BDD "A description the backend refuses shows the error under the description" (the backend now counts as the form does, so no valid description is refused; TL decision 2) and the contract tests of the removed side channel (`SaveRejected` mapping, `ApiErrorBodyDto`, the throwing-API mapping), whose behaviour moved into `mc_api_errors` and is tested there.
- Changed by the TL's decisions: BDD "A name the backend refuses ..." now uses `duplicate_name` (it used 31 flags); BDD races "Another user signing in during the save ..." now expects `{1}` change (item 6: what was written is announced); `:flow_scope_test` "an editor closed while its save is held ..." now expects one `readingLists` announcement (item 6).
- No other test deleted, skipped or weakened; T-0047's library tests are unchanged and green; no `// ignore:`.

**Results** on the merged tree (`origin/main` `1d9bde1`):
- Gates [PASS](../evidence/T-0048/engineer/T-0048-AC8_gates.md): `test //...` **137/137** (the feature, `//app/...`, `mc_test_steps`, `l10n_check`, `mc_forms`, `mc_ds_forms`, `mc_api_errors` and `mc_fixtures_library` uncached first), lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, fixtures check, relative paths, the four AC7 checks. **Coverage:** library_reading_list_editor 723/736 = 98.2 %, library_wiring 37/37 = 100 %, app_core 354/368 = 96.2 %, publishing_wiring 47/47 = 100 %, mc_forms 286/286 = 100 %, mc_api_errors 60/60 = 100 %, mc_fixtures_library 203/206 = 98.5 %. Locks unchanged.
- AC7: [byte identity 12 of 12](../evidence/T-0048/engineer/T-0048-AC7_matches_build_runner.md), [cutoff](../evidence/T-0048/engineer/T-0048-AC7_cutoff.md), [not committed](../evidence/T-0048/engineer/T-0048-AC7_generated_not_committed.md), [gen-l10n parity](../evidence/T-0048/engineer/T-0048-AC7_gen_l10n_parity.md); after `tool/ide_sync --env dev`, [`T-0042-AC4_safety.sh`](../evidence/T-0048/engineer/T-0042-AC4_safety.md) PASS; `--clean` afterwards.
- **Mutations:** 57 in the full run, [55 killed](../evidence/T-0048/engineer/mutations.log); the other two were defects of the script, both fixed and re-run: AC5-a no longer matched the changed home code (not applied), and AC6-u removed only one of the two guards item 5 asks for, so the other one still held (survived; it now removes both). Re-run: [2 of 2 killed](../evidence/T-0048/engineer/mutations_rerun.log). So **57 of 57** are killed by a failing test, none by a compile error.
- **e2e** on a fresh `mc-T-0048-engineer-*` (iOS 26.2, deleted): 4 of 4 PASS, screenshots 30–38 refreshed ([summary](../evidence/T-0048/engineer/mini_client/e2e-summary.md)).
- **Goldens:** none changed (7 pass as they were).
- AC traceability: [test_names.txt](../evidence/T-0048/engineer/test_names.txt), 131 names (AC1 15, AC2 28, AC3 21, AC4 7, AC5 6, AC6 42, AC7 7, AC8 10).

