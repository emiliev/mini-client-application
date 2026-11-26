# F-0048: The form/wizard exemplar: flow results through the router, wizard steps as flow pages, and two kit gaps

- **Date:** 2026-11-27
- **Author:** crew: Engineer (T-0048)
- **Type:** Design record / Lesson / Kit gap
- **Related:** T-0048, P1-20, plan 01 §4.3, R15, R17, F-0040, F-0045, F-0038

## Summary
`library_reading_list_editor` is the fourth exemplar (FW): a three-step wizard that creates or edits a reading list and **ends with a result**, which the wiring hands back to whoever opened it. It is the first use of plan 01 §4.3's flow results, so fact 1 is the pattern the bricks copy. **No codegen shim failed on a real-world case**: the 12 freezed, json, retrofit and injectable outputs equal build_runner's, including a flow-scoped `@lazySingleton` bloc with `@disposeMethod` (fact 2). Two kit gaps were handled with the kits' public API and need a TL decision (facts 3 and 4).

## 1. The flow-result pattern (plan 01 §4.3): for the bricks
Three layers, each with one job:

| Layer | Code | What it does |
|---|---|---|
| Feature | a bloc calls `FeatureFlowController.complete(id)`; the flow widget takes `onComplete: ValueChanged<ReadingListId?>` and passes `FeatureFlow(onComplete: (r) => onComplete(r as ReadingListId?))` | Ends with the feature's own result type (exported by the barrel, R4). `complete()` with no argument ends it with null (a declined sign-in, Close after the session changed). Back from step 1 pops the route without calling `onComplete`. |
| Wiring | the route's `build` returns `FlowResultRoute<String>(builder: (complete) => targets.newReadingList(onComplete: complete))`; `LibraryRouteTargetsImpl` maps `ReadingListId?` to `String?` | `FlowResultRoute` (app_core) pops its own route with the result. Features never share types, so the targets map the feature's type to the app-level one. |
| Caller | `final id = await AppFlows.createReadingList(router)` (app_core) | `GoRouter.push<T>` completes with the popped result, or null after Back. `AppFlows` names each result route's location and type once. A feature that needs another feature's result asks its own navigator; the navigator implementation awaits the `AppFlows` entry and maps the result (`src/mappers/`). |

Gotchas met on the way:
- **`GoRouteData.build`'s context is not inside the route.** go_router calls the builder with the navigator's context, so `ModalRoute.of(context)` there is the route around the whole router. `FlowResultRoute` is a widget, so its own context is inside the page, and `completeRoute` finds the right route.
- **Only `Navigator.pop` completes `push<T>`.** go_router 17.5 builds its navigator with `onPopPage`; `pop(result)` reaches it and completes the match's completer. `Navigator.removeRoute(route, result)` on a page-based route skips `onPopPage`, so go_router's configuration and the caller's future would be left behind. `completeRoute` therefore pops only when its route is current; with a sheet or dialog above it, it does nothing (it never pops what is above). A flow completes from a tap on its own page, so this does not happen in practice.
- **A deep link has no caller.** `miniclient://app/me/lists/new` opens the editor as the only route; popping the last page would trip go_router's assert, so completing a first route goes home instead.
- `AppLocations.editReadingList(id)` encodes the id as go_router_builder does (`Uri.encodeComponent`); the wiring's drift test checks `'a b'` too.

## 2. Wizard steps are flow pages; the wizard lives in a flow-scoped bloc
- Each step is a `McFlowPage` (`details`, `comics`, `review`), so the iOS back swipe and the app bar's back on step 2 or 3 return to the step before, inside the flow. Step 1 is the flow's root; its back leaves the editor.
- **The values cannot live in the flow state.** `FeatureFlow` restores, on a pop, the state the lower page had, which drops whatever was entered on the popped page (by design, F-0018). The kit's `WizardController` keeps one form over all steps, so it must outlive the pages: `ReadingListEditorBloc` is a **`@lazySingleton` of the flow's own container**, and every step page provides it with `BlocProvider.value(value: context.di<ReadingListEditorBloc>())`. Its `close()` carries `@disposeMethod`, so injectable registers `dispose: (i) => i.close()` and the flow's container closes it with the flow. Page-only state (the comic search) is an ordinary `@injectable` bloc per page.
- **Two-way step sync.** The wizard is authoritative: its `onState` writes `step` into the flow state (pages open and close), and the bloc listens to `FeatureFlowController.states` so a pop the flow reports is applied with `WizardController.back()`. Neither side echoes, because each only acts when the two disagree.
- **A page below the current one** is still mounted (and visible during a back swipe), so `EditorStepBar` binds `McWizardStepper.fromState` only on the page of the current step; other pages show their own step with both buttons off.
- **No pop while saving.** The review page wraps itself in `PopScope(canPop: !saving)`, which also disables the iOS swipe on that page. The outer route cannot be swiped away meanwhile, because flow_builder's own `PopScope(canPop: false)` (with more than one page) is registered on it.

## 3. Kit gap: a server-side field error has no way into the wizard (TL decision)
The task asks that a `400` from the backend go back to the right step and show under the right field. The kits cannot express that directly:
- `ApiFailure` (`mc_api_errors`) keeps the status and a message, not the error body, so `error.code` and `error.parameter` are lost by `ApiFailure.from`. The repository therefore reads the `DioException`'s body itself (`ApiErrorBodyDto`) and returns a feature `SaveFailure` (`SaveApiFailure` / `SaveRejected(field, code)`).
- `WizardController`'s `SubmitAction` must return `Result<R, ApiFailure>`, and the controller has no call to set a field error or go to a step.

What the exemplar does, with public API only and each call used for its documented purpose:
1. `ServerVerdicts`, a **feature rule** on each field (F-0045 item 4): "the backend refused exactly this value". It fails while the field's wire value equals the refused one, so the step is invalid, Next and Finish are blocked, and the error shows under the field until the user changes it.
2. The save keeps the `SaveRejected` aside and returns the kit an `ApiFailure.clientError(400, ...)`. Once `complete()` has returned (while it runs, `setValue` is ignored), the bloc records the verdict, calls `setValue(field, sameValue)` (the kit re-checks every rule on a change and clears the failed submit), then `back()` until the field's step.

**Decision for the TL:** keep this (it is kit-conformant, but every FW brick would copy the side channel and the "same value" re-check), or add a kit API in a small task, for example `WizardController.reject(Map<String, FieldError>)` (errors until the value changes; goes to the first rejected step) plus the error body on `ApiClientError` (`code`, `parameter`). The exemplar would then drop `ServerVerdicts` and `_rejection`.

## 4. Kit and contract disagree on what a character is (TL decision)
`mc_forms` counts user-perceived characters (grapheme clusters, T-0045 review); `mc_fixtures_library` counts runes (T-0047 CONTRACT.md). A name of 31 flag emoji is 31 characters to the form and 62 to the backend, whose limit is 60, so the client lets it through and the server answers `400 invalid_name`. The same holds for the description (141 flags: 141 against 282, limit 280). The exemplar's AC2 scenarios use exactly that real disagreement to reach the backend's verdict. **Decision:** align them (the contract counts graphemes, or `Validators.maxLength` gets a rune mode for wire limits), or keep the disagreement as the realistic case it is. If they are aligned, the two AC2 scenarios need another way to make the backend refuse a value (there is no `FailureKind` with a custom body today).

## 5. Other facts
1. **`Bloc.isClosed` stays false while handlers run.** bloc 9's `close()` waits for the running handlers before it closes the state stream, so a save in flight sees `isClosed == false` long after the flow left the screen. "Write only while the editor is open" therefore uses the bloc's own flag, set at the start of `close()` (test: "an editor closed while its save is held hands out nothing").
2. **Every await is a session boundary (F-0040 fact 21), also between two writes.** The edit save checks the session epoch and the open flag before the `PUT` of the details and again before the `PUT` of the items; a result that arrives for an ended session is never handed out (the editor shows "You are no longer signed in as before", Close ends it with no result). A list created for user A stays A's; it is just not returned to a caller now in B's session.
3. **No list-length rule in `mc_forms`.** `required` handles an empty list; the "at most 100 comics" rule is a feature rule (`_atMost`). A generic `Validators.maxItems` belongs in the kit (follow-up).
4. **No bound widgets besides `McFormTextField`** (T-0045 follow-up): the visibility (`McSegmented`) and the picked comics (`McChipGroup.multi`) are bound by hand, and the comics error is a hand-made live-region text. `McFormTextField` also has no `maxLines`, so the description is one line (follow-up).
5. **A field without a blur needs an explicit touch.** The kit shows an error once a field is touched; a text field is touched on blur, a picker is not. The bloc touches the comics field on every pick.
6. **No-change edit:** "only the parts that changed" is decided against the list the backend last returned (`_saved`), not the fields' `dirty` (which compares with the initial value): after the details saved and the items failed, Retry sends only the items.
7. **`l10n_check` names the ARB files by the package directory.** The set must be `library_reading_list_editor_<locale>.arb`; the gen-l10n output file and class (`reading_list_editor_l10n.dart`, `ReadingListEditorL10n`) are free.
8. **Testing:**
   - A row of a lazy list above the viewport is in the cache area, which finders treat as offstage: find it with `skipOffstage: false` and `ensureVisible`, or `scrollUntilVisible` for rows not built yet.
   - A state that waits for the app forever (the sign-in) must not show a spinner, or `pumpAndSettle` times out; it shows a static message.
   - In Flutter 3.47 `SemanticsFlags.isSelected` is a `Tristate`, and `ReorderableListView.onReorder` is deprecated for `onReorderItem` (whose target index already accounts for the removed item).
   - A Gherkin `{'...'}` parameter cannot hold `{` or `}`, so request bodies are asserted with a data table of JSON fragments (the generic step `the backend received {route} with the body`).
   - `flutter drive` starts each e2e target with a fresh app container, so the session does not carry over between targets; the journeys still accept an already signed-in start.
9. **The sign-in sheet moved to `app_core`.** Two wirings need it now, so `requestFixtureSignIn` and the sheet live in `app_core/src/sign_in/` with a `reason` line; publishing_wiring calls it. Its keys are `app.sign_in.*` (the comics e2e journey follows).

## Evidence
`documents/evidence/T-0048/engineer/`: byte identity, cutoff, not committed, gen-l10n parity, gates, mutations, e2e summary and screenshots.

## Implications / actions
- TL decisions on facts 3 and 4 before the FW bricks copy the editor.
- Kit follow-ups: `Validators.maxItems`, bound segmented and choice-list widgets, `McFormTextField.maxLines`.
