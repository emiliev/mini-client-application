# T-0075: `mcgen` form/wizard (FW) archetype: `library_reading_list_editor` and `auth_signin` regenerate byte for byte

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-28 `071062c4`; review-first and merge gates per ADR-0015) |
| Owner | crew: Engineer (Sonnet, worktree); follows the T-0069/T-0072/T-0073 pattern |
| Verification | ADR-0015: `/code-review`, one fix round, TL merge gates |
| Branch | `fleet/T-0075-mcgen-form-wizard` |
| Created | 2026-11-28 |
| Depends on | T-0065, T-0069 (ADR-0017), T-0072/T-0073 (`OptionsReader`, lint lessons), T-0048 (FW exemplar), T-0066 (`auth_signin`, a second FW-style module) |
| Related | plan 02 §2.3–§2.7, P2-05; F-0069, F-0072, F-0073 (**lint must cover every spec role the emitters use; batch specs fail otherwise**); F-0048 (flow results, `FormController`/`WizardController`, `reject()`), F-0066 |

## Goal
Add the FW archetype. The exemplar `library_reading_list_editor` (multi-step wizard, flow result, server-error mapping) and `auth_signin` (a single-step form) must **both** round-trip.

## Scope
- **In:**
  - `emit/feature_form_wizard/` and `bricks/feature_form_wizard_*`.
  - Specs for both modules (`exemplar: true`).
  - Keep markers that are comment-only and few.
- **The template covers:**
  - steps and fields with validators from `mc_forms`;
  - server typed codes mapped to fields;
  - the flow result type;
  - `FlowResultRoute`/`AppFlows` usage, documented. Wiring stays hand-written until T-0074.
  - writes pinned with `authPinned`, and the session-epoch rule;
  - the bloc guards.
- **Lint and errors:**
  - Lint checks every role the emitters read, so a spec that passes lint generates code that compiles. Learn from T-0072 and T-0073.
  - Archetype errors print the spec path and message.
- **Reuse:**
  - Reuse `emit/common`, and keep additions there additive.
  - Every existing `--check` must stay up to date: `characters_list`, `discovery_search`, `characters_search`, `comics_details` and `characters_details`.
- **Parallel work:** T-0074 (wire and buildgen) and T-0076 (the DB archetype) are running. Own `emit/feature_form_wizard/` and `bricks/feature_form_wizard_*`. `archetypes.dart` gets one line.
- **Out:** behaviour changes.

## Acceptance criteria
- **T-0075-AC1:** `gen --check` exits 0 for both modules. A one-field spec change exits 1 and names the file.
- **T-0075-AC2:** both features behave unchanged. Bazel tests and app tests are green, and the diffs are only markers, specs and manifests.
- **T-0075-AC3:** throwaway FW probes (temp dir) generate, analyse clean, and pass BDD under Bazel. Use at least two shapes: a 3-step wizard with a result, and a one-step form. Include at least one lint-rejection test per spec role.
- **T-0075-AC4:**
  - Gates: `test --lockfile_mode=error //...`, lint, the format gate, `T-0065-AC5_gates.sh`, and all five existing `--check` runs up to date.
  - Lockfiles unchanged.
  - Every cited test exists.
  - A short finding with the hand share.

## Log
- 2026-11-28: Created and dispatched (TL), as part of the third wave.
- 2026-11-28 (Engineer, Sonnet): Done on `fleet/T-0075-mcgen-form-wizard`.
  - **Archetype** `form_wizard` (`lib/src/emit/feature_form_wizard/`, bricks `feature_form_wizard_di`, `_package` and `_build`). The spec's `options` carry names, a `types` map (name to file or `package:` URI), the flow's arguments, result, pages and state fields, the barrel, the root imports and the architecture test's facts.
  - **Exemplars:** `library_reading_list_editor` (three steps, nullable result, keyed flow) and `auth_signin` (one form, two arguments, non-null result) each have a spec (`exemplar: true`) and a manifest. Each exemplar's diff against `main` is the spec, the manifest and whitespace-only realignments of Examples tables (F-0075 section 3.1); no keep region exists.
  - **Managed:** barrel, DI initializer, root imports, navigator, flow state, flow, ARBs, `l10n.yaml`, `pubspec.yaml`, `.feature` files, architecture test. **Owned:** the domain, the form's rules, the bloc, the pages, the env, the steps, the contract and guard tests, the golden, BUILD (hand share 89 % and 95 %, F-0075 section 1).
  - **Skeleton** (`options.skeleton`): a new module gets an owned bloc (the guards: closed means stopped, one submit at a time, the epoch rule, `authPinned` write, `reject()` for a `400`), repository, form rules, step page, env, eight steps, flow-scope test and BUILD.
  - **Probes** `zz_fw_probe` (3 steps) and `zz_fw_plain` (1 step): `tool/mcgen/tool/T-0075-AC3_fw_probe.sh`; gen, idempotent `--check`, `build --config=lint` and uncached `test`, 7 and 7 BDD scenarios.
  - **No change to `emit/common`.** `archetypes.dart`: one import and one line.
  - **Tests:** nothing deleted or weakened. `tool/mcgen/test/form_wizard_test.dart` is new.
  - **Pitfalls and hand share:** [F-0075](../findings/F-0075-mcgen-form-wizard.md).

## Outcome
**Status: In Verification.** Both exemplars regenerate byte for byte (17 and 15 rendered files). Two throwaway modules generate, analyse clean and pass their BDD under Bazel.

| AC | Evidence |
|---|---|
| T-0075-AC1 | `tool/mcgen/test/form_wizard_test.dart`:<br>- `T-0075-AC1 mcgen gen library_reading_list_editor --check exits 0 against the exemplar` and `... gen auth_signin --check ...`<br>- `T-0075-AC1 the round-trip golden of library_reading_list_editor: compareToExemplar finds the render identical to the real exemplar` (and `of auth_signin`)<br>- `T-0075-AC1 a changed spec field makes --check exit 1 and name the file`<br>- `T-0075-AC1 a flow argument renamed in the spec changes the flow, and --check names it`<br>- `T-0075-AC1 gen writes only the manifest into an exemplar, and the committed manifest is the one it writes` |
| T-0075-AC2 | - [T-0075-AC2_bazel_test_after.log](../evidence/T-0075/T-0075-AC2_bazel_test_after.log): both modules and `//app/...`, 48 of 48 uncached<br>- `git diff` of the exemplars: specs, manifests, and whitespace in two Examples tables<br>- `T-0075-AC2 an exemplar renders only the managed layer: ...`, `T-0075-AC2 the exemplars have no keep region: ...` |
| T-0075-AC3 | - [T-0075-AC3_fw_probe.md](../evidence/T-0075/T-0075-AC3_fw_probe.md): PASS for both probes<br>- `form_wizard_test.dart`: `T-0075-AC3 both probe specs lint clean and render the same bytes in two roots`, `... the probes are their own modules, not an exemplar with names swapped`, `... the template covers every behaviour the task names`, `... the skeleton files are owned and the managed layer is not`, `... a step no template knows is written once, as a failing stub`, `... a prose slot no template uses fails gen, naming it`, `... a missing de string is a lint error, not pseudo text`<br>- one lint-rejection test per spec role: `T-0075-AC3 unknown and missing options`, `... types: every type a template writes is declared, with a file`, `... root imports and the flow: roles the flow and the flow scope read`, `... flow arguments and the flow state`, `... the skeleton: steps, fields, strings, the result and the page`, `... an archetype error prints the spec path and the message, and gen prints no stack` |
| T-0075-AC4 | - gate logs in `documents/evidence/T-0075/` (see the handoff)<br>- `T-0075-AC4 every existing exemplar still round-trips` (the five existing `--check`s) and `T-0075-AC4 form_wizard is registered, and only for features`<br>- [F-0075](../findings/F-0075-mcgen-form-wizard.md) |

- **Hand share** (tool/loc): `auth_signin` 1,278 of 1,430 (89 %), `library_reading_list_editor` 3,163 of 3,315 (95 %).
- **Keep regions:** none.
- **Follow-ups (for `pending-work.md`):**
  - once T-0074 lands, `BUILD.bazel` and `flow_scope.dart` leave this archetype;
  - the skeleton knows text fields only (no choice, picked list, sign-in gate or edit mode);
  - a bloc template covering both exemplars would be a code DSL: not planned.

## Review round (ADR-0015 single fix round)
- 2026-11-28 (Engineer): six important findings, each with a test in `form_wizard_test.dart`.
  1. **One-step form:** the last step page now shows the saving indicator and `wizard.failure`, as a review does. `zz_fw_plain` has a failure scenario (`server_error`, then a retry) and passes under Bazel (7 of 7 scenarios).
  2. **Placeholders:** lint requires `Step` to have the int placeholders `step` and `total`, `TooLong` the int `max`, and every other required key none.
  3. **Flow state:** lint reports a required flow-state field (non-nullable, no default) that the state expression does not set. The dead loop is gone.
  4. **Names in expressions:** the type check covers the whole page widget, its `when` and `flow.key`, and `flow.dart` passes all three through `refs`, so a type there is imported.
  5. **Escaping:** every spec string written into a Dart literal (labels, request path, id key, body keys) goes through the shared `dartString` helper in `core/naming.dart`, which LD, SC and SR already use, so `emit/common` needed no new one. Tested with a quote, a backslash and a dollar sign.
  6. **Duplicate keys:** lint rejects a request body key written twice across fields and `submit.extra`.
- **Nits fixed:** the flow-argument check matches by word, and a bad name is reported at `options.flow.args[i].name` or `options.flow_state.fields[i].name`.
- **Accepted by the TL:** the hand share (89 % and 95 %) and the whitespace-only realignment of one Examples table in each of `auth_signin_l10n.feature` and `reading_list_editor_create.feature`.
- **After T-0074 merges:** drop `BUILD.bazel` and `flow_scope.dart` from the archetype, add the root-import packages to the pubspec, and switch the probe script to gen, wire, buildgen.

## Contract switch (after T-0074)
- 2026-11-28 (Engineer): merged `origin/main` (T-0074).
  - **Dropped from the archetype:** `BUILD.bazel` (`skeleton_build.dart`, brick `feature_form_wizard_build`), `lib/src/di/flow_scope.dart` and the `options.root_imports` key. The round-trip already ignores both files (`defaultExemplarIgnores`). The exemplar specs lost `root_imports`, the `flow_scope.doc` slot and the types only the root imports used. Both exemplars still round-trip, and their pubspecs are unchanged.
  - **Pubspec:** adds `mc_di`, `mc_monitoring` and `mc_session` (what the flow scope imports). `dio` stays with the module's own use-graph and `deps`, since `auth_signin` has none.
  - **Probe script:** `gen`, then `wire`, then `buildgen` per probe. Both probes pass under Bazel with 7 of 7 scenarios each.
  - **`wire` and a managed FW module:** `T-0075-AC3 wire only warns about a form_wizard flow and lists it as not wired; ...` runs `gen`, `wire` and `buildgen` in a temp repo: a warning, a catalogue note, exit 0, and both `--check`s exit 0. In the repo itself, a probe left in the tree makes only the workspace `pubspec.yaml` out of date, as for any uncommitted module.
  - **Gates:** `T-0065-AC5_gates.sh`, the seven `gen --check`s, `wire --check` (16 files), `buildgen --check` (11 files), `check --all` and `test --lockfile_mode=error //...` (247 of 247) pass.

## Merge (TL)
- 2026-11-28: `/code-review` found 6 important skeleton and lint gaps and 2 nits. Fix round `8729f2af` fixed all of them; escaping uses `dartString`.
- Contract switch to T-0074 at `25fe1327`: BUILD, `flow_scope` and `root_imports` are dropped; the pubspec gains `mc_di`, `mc_monitoring` and `mc_session`; the probe script runs gen → wire → buildgen; FW flows produce a warning (not wired).
- TL checks: the exemplar diffs are specs, manifests and two accepted whitespace realignments in Examples tables; no deleted or skipped tests.
- The TL merged `--no-ff` after T-0076 and resolved the `archetypes.dart` registry conflict by keeping both entries. On the merge result:
  - 247/247 tests, lint clean, format gate passed;
  - mcgen gates passed;
  - `wire`, `buildgen` and `check --all` (8 modules) are up to date, and all 8 round-trips pass.
- Hand share 89 % and 95 %. New FW modules get a text-fields-only skeleton (F-0075 §1, accepted).
