# T-0075: `mcgen` form/wizard (FW) archetype: `library_reading_list_editor` and `auth_signin` regenerate byte for byte

| Field | Value |
|---|---|
| Status | In Progress |
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
