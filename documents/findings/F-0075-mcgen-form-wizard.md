# F-0075: The form/wizard (FW) archetype: what is a template, what stays hand-written, and the pitfalls

- **Date:** 2026-11-28
- **Author:** crew: Engineer (T-0075)
- **Type:** Design record / Lesson
- **Related:** T-0075, P2-06, ADR-0017, ADR-0016, ADR-0015, F-0069, F-0072, F-0073, F-0048, F-0066

## Summary
`mcgen gen library_reading_list_editor --check` and `mcgen gen auth_signin --check` both exit 0. The `form_wizard` archetype renders 17 and 15 files, each equal to the exemplar byte for byte. It reads one `options` block (names, types, flow arguments, result, pages, flow-state fields, root imports, architecture-test facts) plus the core spec's navigator, strings and BDD.

- **Rendered (managed):** the barrel, the DI initializer, the navigator, the flow state, the flow, the three ARBs, `l10n.yaml`, `pubspec.yaml`, the `.feature` files and the architecture test.
- **Hand-written (owned):** the domain (API, DTOs, repository), the form's rules, the bloc with its events and state, the step pages and widgets, the test env, every step file, the contract and bloc-guard tests, the golden.
- **Two shapes, one template:** a three-step wizard whose flow has an argument (`editing`), a key and a nullable result; a one-form flow with two arguments, a non-null result and no key.
- **A skeleton** (`options.skeleton`) writes a working owned module from a spec: a `WizardController` over text fields (a form is a wizard of one step), one write pinned to the session epoch, the flow result and the server's verdicts mapped to the field they name. Two throwaway modules, `zz_fw_probe` (3 steps, result `ShelfId`) and `zz_fw_plain` (1 step, result `NoteId`, a field whose name differs from its request key), generate, analyse clean under `mc_analysis`, and pass their BDD (7 and 7 scenarios), flow-scope and architecture tests under Bazel ([T-0075-AC3_fw_probe.md](../evidence/T-0075/T-0075-AC3_fw_probe.md)).
- **Nothing was added to `emit/common`.** `archetypes.dart` gained one import and one line. `pseudo()` and `kit_symbols` are reused as they are.

## 1. Hand share (tool/loc on the committed manifests)
| Module | source hand / scaffold | test hand / scaffold | overall hand |
|---|---|---|---|
| `auth_signin` | 481 / 83 | 797 / 69 | 1,278 of 1,430 (89 %) |
| `library_reading_list_editor` | 1,712 / 81 | 1,451 / 71 | 3,163 of 3,315 (95 %) |

(`characters_list`: 18 %, `characters_search`: 54 %, `comics_details`: 63 %.) This is the highest share of any archetype, and it is a decision, not an oversight:

- **The bloc is the feature.** `auth_signin`'s bloc is a `FormController` with a typed failure, a signed-in latch and an undo of a sign-in that lands after the flow closed. The wizard's bloc is a sign-in gate, an edit-mode load, a diff-based save of two writes, a bus announcement and the session epoch checked after every await. Rendering both from one spec is a code DSL, not a template. What they share (the guards: closed means stopped, one submit at a time, the epoch rule, `authPinned` writes, `reject()` for a `400`) is written once in the **skeleton's** bloc, so a new module gets it and the probes test it.
- **The form's rules are domain code** (`_comicsRequired`, `_atMost`, `serverError(code)` with the backend's `too_many_comics`), as are the models, DTOs and the mapper.
- **The pages are widgets** (P2-09 will design size-driven variation).
- **Steps and the env** read module widgets by key, and the env's fixture lookups are top-level declarations that ADR-0016 keeps out of keep regions. The skeleton writes eight step files from templates (`the_error_shows_under_the_field`, `i_enter_in_the_field`, `i_am_on_step`, ...); an exemplar's are its own.
- **Keep regions: none.** Nothing of the managed layer varies in a body. Every variable thing is data in the spec (an argument, a page, a type), so no keep region was needed.

## 2. The contract between the templates and a module's own files
`options.types` maps every name a managed file writes to the file that declares it (a path under `lib/src/`, or a `package:` URI); mcgen writes the imports, so the spec is the only place a name is listed. Lint requires each name that flow arguments, state fields, the result type and cast, pages, defaults, the `state:` expression and the navigator's signatures use to be in it, so a spec that lints clean generates a flow that compiles.

| Option | What it drives |
|---|---|
| `pascal`, `stem`, `l10n_file` | class names (`AuthSignIn`), file stems (`auth_signin_flow.dart`) and the gen-l10n output (`reading_list_editor_l10n.dart`), which the package name does not always give |
| `barrel`, `root_imports` | the barrel's `show` list and `RootImport<T>()` lines |
| `flow.args`, `flow.result`, `flow.state`, `flow.key`, `flow.pages` | the flow's constructor, `onComplete`, the `FeatureFlow` state and key, and one `McFlowPage` per page (a condition, a `const` flag) |
| `flow_state.fields` | the freezed state, with `@Default` |
| `architecture` | the tag and the "more than N pure files" bound of the architecture test |
| `arb` | `block_placeholders`: both exemplars write a description with placeholders on lines of its own |
| `prose` | every doc comment a template writes (checked both ways: an unused slot fails gen) |
| `skeleton` | the first writes of a new module (absent in an exemplar) |

## 3. Pitfalls (each cost a round)
1. **A second look at the Examples tables.** Both exemplars had hand-aligned tables (a combining accent; one very long cell). The generator pads by string length, so three whitespace-only lines in `auth_signin_l10n.feature` and `reading_list_editor_create.feature` were realigned. This is the same accepted change as T-0073's.
2. **`<<<Name>>>` and `Type<<Result>>?`.** In a template, `List<<<Result>>?>` is `List<` + the variable + `?>`. Writing `<<<Result>?>` leaves the variable unclosed and formats as garbage. Count the angle brackets.
3. **A kit name may already be registered.** Registering `Monitoring` from `options.types` threw "already defined". The archetype registers a type only when the kit table does not already know it, and never one the skeleton defines.
4. **A type found by a regex needs a left boundary.** `demoAccounts` contains `Accounts`; the identifier scan took it for a type until it got a lookbehind.
5. **An owned file is written once.** Regenerating a probe in place changed nothing after a template fix. The probe script and `/tmp` helper delete the module first.
6. **`bddSetUpAll` in the env, and `setUpAll(bddSetUpAll)` in the flow-scope test.** Without them `useFixtureSet` fails with "Registered: []". The env registers the fixture sets of `skeleton.fixtures` (`identity.default` is in `mc_fixtures_identity`).
7. **Hold the write after the last tap.** A scenario that holds `POST` before opening the flow never reaches the review. Hold it right before the last tap.
8. **Steps with a data table** (`the backend received {..} with the body`) take a table, not a string; a scenario that passes a string does not compile.
9. **`const` for `McFlowPage` and the flow state.** The analysis aspect asked for `const` (prefer_const_constructors), so a spec states `const: true` on a page and `const` in `flow.state`.
10. **Run the shared format gate, never `dart format` by hand.** The generated probes are formatted by mcgen itself; the gate checks the emitters and tests.

## 4. What P2-07 and later can reuse
- The `options.types` + `refs()` pattern: a spec lists where each name lives, the emitter writes `ref()` markers, the resolver writes imports.
- `skeleton.dart`'s owned first writes and the probe script `tool/mcgen/tool/T-0075-AC3_fw_probe.sh` (two probes, one script).
- The lint style: every role an emitter reads has a message, and every lint rule has a rejection test (`T-0075-AC3 lint ...` in `form_wizard_test.dart`).

## 5. Not done, and why
- **`BUILD.bazel` and `flow_scope.dart`** are `mcgen buildgen`'s and `mcgen wire`'s since T-0074. The archetype writes neither; the round-trip ignores both; the pubspec lists `mc_di`, `mc_monitoring` and `mc_session` (what the flow scope imports); `options.root_imports` is gone. `wire` does not route a form_wizard flow yet (P-128 (e)): it warns, adds a catalogue note, and fails neither `wire` nor `wire --check`.
- **No bloc, event or state template for an exemplar.** See section 1; the skeleton is the template.
- **A skeleton supports text fields only.** A choice (an enum such as a visibility), a picked list, a gate (`requestSignIn`) and edit mode are hand-written, as in both exemplars.
- **The skeleton's request goes through `Dio` directly** (one `POST`, a response with an id), not a retrofit API with DTOs: it keeps the probe's codegen to freezed, injectable and gen-l10n. The exemplar wizard uses retrofit.

## Evidence
- `T-0075-AC1 *`, `T-0075-AC2 *`, `T-0075-AC3 *` and `T-0075-AC4 *` in `tool/mcgen/test/form_wizard_test.dart`.
- The probes under Bazel: [T-0075-AC3_fw_probe.md](../evidence/T-0075/T-0075-AC3_fw_probe.md).
- Hand share: `fvm dart run tool/loc/bin/loc.dart . --json out.json`, modules `auth_signin` and `library_reading_list_editor`.
