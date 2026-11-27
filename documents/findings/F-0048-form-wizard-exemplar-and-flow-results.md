# F-0048: The form/wizard exemplar: flow results through the router, wizard steps as flow pages, and two kit gaps

- **Date:** 2026-11-27
- **Author:** crew: Engineer (T-0048)
- **Type:** Design record / Lesson / Kit gap
- **Related:** T-0048, P1-20, plan 01 §4.3, R15, R17, F-0040, F-0045, F-0038

## Summary
`library_reading_list_editor` is the fourth exemplar (FW): a three-step wizard that creates or edits a reading list and **ends with a result**, which the wiring hands back to whoever opened it. It is the first use of plan 01 §4.3's flow results, so fact 1 is the pattern the bricks copy. **No codegen shim failed on a real-world case**: the 12 freezed, json, retrofit and injectable outputs equal build_runner's, including a flow-scoped `@lazySingleton` bloc with `@disposeMethod` (fact 2). The review round closed the two kit gaps the first handoff worked around (facts 3 and 4), on the TL's decisions.

## 1. The flow-result pattern (plan 01 §4.3): for the bricks
Three layers, each with one job:

| Layer | Code | What it does |
|---|---|---|
| Feature | a bloc calls `FeatureFlowController.complete(id)`; the flow widget takes `onComplete: ValueChanged<ReadingListId?>` and passes `FeatureFlow(onComplete: (r) => onComplete(r as ReadingListId?))` | Ends with the feature's own result type (exported by the barrel, R4). `complete()` with no argument ends it with null (a declined sign-in, Close after the session changed). Back from step 1 pops the route without calling `onComplete`. |
| Wiring | the route's `build` returns `FlowResultRoute<String>(builder: (complete) => targets.newReadingList(onComplete: complete))`; `LibraryRouteTargetsImpl` maps `ReadingListId?` to `String?` | `FlowResultRoute` (app_core) pops its own route with the result. Features never share types, so the targets map the feature's type to the app-level one. |
| Caller | `final id = await AppFlows.createReadingList(router)` (app_core) | `GoRouter.push<T>` completes with the popped result, or null after Back. Since T-0049 (F-0049) the future **always** completes: with the result, or with null when the route goes away (Back, or a `go` that replaces it), via the `FlowCall` passed as `extra`. `AppFlows` names each result route's location and type once. A feature that needs another feature's result asks its own navigator; the navigator implementation awaits the `AppFlows` entry and maps the result (`src/mappers/`). |

Gotchas met on the way:
- **`GoRouteData.build`'s context is not inside the route.** go_router calls the builder with the navigator's context, so `ModalRoute.of(context)` there is the route around the whole router. `FlowResultRoute` is a widget, so its own context is inside the page, and `completeRoute` finds the right route.
- **Only `Navigator.pop` completes `push<T>`.** go_router 17.5 builds its navigator with `onPopPage`; `pop(result)` reaches it and completes the match's completer. `Navigator.removeRoute(route, result)` on a page-based route skips `onPopPage`, so go_router's configuration and the caller's future would be left behind. So `FlowResultRoute` pops only while its route is current. **A result that arrives under an overlay** (a dialog or sheet above the route) is kept and handed over as soon as the route is current again: the state depends on its `ModalRoute`, whose `isCurrent` change brings `didChangeDependencies`, and the pop runs after that frame. It never drops the result and never pops what is above (review item 8; a first version dropped it).
- **A deep link has no caller.** `miniclient://app/me/lists/new` opens the editor as the only route; popping the last page would trip go_router's assert, so completing a first route goes home instead.
- `AppLocations.editReadingList(id)` encodes the id as go_router_builder does (`Uri.encodeComponent`); the wiring's drift test checks `'a b'` too.

## 2. Wizard steps are flow pages; the wizard lives in a flow-scoped bloc
- Each step is a `McFlowPage` (`details`, `comics`, `review`), so the iOS back swipe and the app bar's back on step 2 or 3 return to the step before, inside the flow. Step 1 is the flow's root; its back leaves the editor.
- **The values cannot live in the flow state.** `FeatureFlow` restores, on a pop, the state the lower page had, which drops whatever was entered on the popped page (by design, F-0018). The kit's `WizardController` keeps one form over all steps, so it must outlive the pages: `ReadingListEditorBloc` is a **`@lazySingleton` of the flow's own container**, and every step page provides it with `BlocProvider.value(value: context.di<ReadingListEditorBloc>())`. Its `close()` carries `@disposeMethod`, so injectable registers `dispose: (i) => i.close()` and the flow's container closes it with the flow. Page-only state (the comic search) is an ordinary `@injectable` bloc per page.
- **Two-way step sync.** The wizard is authoritative: its `onState` writes `step` into the flow state (pages open and close), and the bloc listens to `FeatureFlowController.states` so a pop the flow reports is applied with `WizardController.back()`. Neither side echoes, because each only acts when the two disagree.
- **A page below the current one** is still mounted (and visible during a back swipe), so `EditorStepBar` binds `McWizardStepper.fromState` only on the page of the current step; other pages show their own step with both buttons off.
- **No pop while saving.** The review page wraps itself in `PopScope(canPop: !saving)`, which also disables the iOS swipe on that page. The outer route cannot be swiped away meanwhile, because flow_builder's own `PopScope(canPop: false)` (with more than one page) is registered on it.

## 3. A server-side field error goes through the kits (TL decision, review round)
The first handoff had no kit way to show a `400` under a field: `ApiFailure` lost the error body, and `WizardController` could not set a field error or go to a step. It used a feature-level "refused value" validator and a side channel. The TL decided kit support instead, since the bricks would copy the workaround:
- **`mc_api_errors`:** `ApiClientError` keeps the error body's `code` and `parameter` (`{"error": {"code", "parameter"}}`, a map or JSON text; null otherwise).
- **`mc_forms`:** `FormController.reject(name, FieldError)` sets a server-side error on the field (touched, so it shows; the form is invalid) until the field's value changes, and a failed submit goes back to idle; `reset` forgets it; a failing rule wins. `WizardController.reject(name, error)` does that and goes to the field's step; it is ignored while completing, after completing and after dispose.
- **The feature:** the bloc maps the `parameter` to a form field (`ReadingListFields.ofParameter`) and calls `wizard.reject(field, serverError(code))`. No side channel, no validator, no "set the same value" re-check.

## 4. The kit and the contract count characters the same way (TL decision, review round)
`mc_forms` counts what a reader sees as one character (grapheme clusters); `mc_fixtures_library` counted runes, so 31 flags passed the form and failed the backend. The library now counts grapheme clusters too (`package:characters`, pure Dart; CONTRACT.md updated, tests for flags and combining accents). The one server-only rule a valid wizard can meet is new: **`duplicate_name`** (a user's list names are unique, case-insensitive after trimming; a renamed list may keep its own name). AC2's "the backend refuses the name" path uses it.

## 5. Other facts
1. **Call `super.close()` first.** bloc 9.2's `isClosed` is true as soon as `Bloc.close()` starts (it closes the event stream first). The first handoff's override awaited its subscriptions before calling `super.close()`, so `isClosed` was still false meanwhile, and the bloc added its own flag. Now `close()` calls `super.close()` first and the bloc uses `isClosed`: after every await (a load, a sign-in, a save) it returns if closed, and `add` is guarded, so leaving mid-load or mid-sign-in neither throws (`Cannot add new events after calling close`) nor reports to monitoring (review item 5).
2. **Whatever was written is announced.** A save that wrote anything publishes `DataChanged('readingLists')` once, also when its second write then failed, or the session or the editor ended (review item 6).
3. **An empty list in edit mode.** "At least one comic" applies to a new list, and to an edited list only once its comics change, so a list that is empty on the backend can be renamed (review item 7).
4. **Every await is a session boundary (F-0040 fact 21), also between two writes.** The edit save checks the session epoch and the open flag before the `PUT` of the details and again before the `PUT` of the items; a result that arrives for an ended session is never handed out (the editor shows "You are no longer signed in as before", Close ends it with no result). A list created for user A stays A's; it is just not returned to a caller now in B's session.
5. **No list-length rule in `mc_forms`.** `required` handles an empty list; the "at most 100 comics" rule is a feature rule (`_atMost`). A generic `Validators.maxItems` belongs in the kit (follow-up).
6. **No bound widgets besides `McFormTextField`** (T-0045 follow-up): the visibility (`McSegmented`) and the picked comics (`McChipGroup.multi`) are bound by hand, and the comics error is a hand-made live-region text. `McFormTextField` also has no `maxLines`, so the description is one line (follow-up).
7. **A field without a blur needs an explicit touch.** The kit shows an error once a field is touched; a text field is touched on blur, a picker is not. The bloc touches the comics field on every pick.
8. **No-change edit:** "only the parts that changed" is decided against the list the backend last returned (`_saved`), not the fields' `dirty` (which compares with the initial value): after the details saved and the items failed, Retry sends only the items.
9. **`l10n_check` names the ARB files by the package directory.** The set must be `library_reading_list_editor_<locale>.arb`; the gen-l10n output file and class (`reading_list_editor_l10n.dart`, `ReadingListEditorL10n`) are free.
10. **Testing:**
   - A row of a lazy list above the viewport is in the cache area, which finders treat as offstage: find it with `skipOffstage: false` and `ensureVisible`, or `scrollUntilVisible` for rows not built yet.
   - A state that waits for the app forever (the sign-in) must not show a spinner, or `pumpAndSettle` times out; it shows a static message.
   - In Flutter 3.47 `SemanticsFlags.isSelected` is a `Tristate`, and `ReorderableListView.onReorder` is deprecated for `onReorderItem` (whose target index already accounts for the removed item).
   - A Gherkin `{'...'}` parameter cannot hold `{` or `}`, so request bodies are asserted with a data table of JSON fragments (the generic step `the backend received {route} with the body`).
   - `flutter drive` starts each e2e target with a fresh app container, so the session does not carry over between targets; the journeys still accept an already signed-in start.
11. **The sign-in sheet moved to `app_core`** (approved). Two wirings need it now, so `requestFixtureSignIn` and the sheet live in `app_core/src/sign_in/` with a `reason` line; publishing_wiring calls it. Its keys are `app.sign_in.*` (the comics e2e journey follows).

## Evidence
`documents/evidence/T-0048/engineer/`: byte identity, cutoff, not committed, gen-l10n parity, gates, mutations, e2e summary and screenshots.

## Implications / actions
- Kit follow-ups (to the TL for `pending-work.md`): `Validators.maxItems`, bound segmented and choice-list widgets, `McFormTextField.maxLines`.
