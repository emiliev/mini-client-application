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
