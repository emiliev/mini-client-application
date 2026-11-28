# T-0077: `mcgen` settings (ST) archetype: `settings_appearance` and `settings_home` regenerate byte for byte

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet), reusing the T-0072 engineer |
| Verification | ADR-0015: `/code-review`, one fix round, TL merge gates |
| Branch | `fleet/T-0077-mcgen-settings` |
| Created | 2026-11-28 |
| Depends on | T-0065, T-0069 (ADR-0017), T-0074 (wire/buildgen, ADR-0018: archetypes don't write BUILD or `flow_scope`), T-0063 (ST exemplar, ADR-0013), T-0070 (`settings_home`) |
| Related | plan 02 P2-05–P2-07; F-0063, F-0070; F-0069, F-0072–F-0076 (lint must cover every role; escape with `dartString`; probe = gen → wire → buildgen) |

## Goal
Add the ST archetype. `settings_appearance` (choices bound to app-wide state, sync status) and `settings_home` (an index with account and About rows) must both round-trip.

## Scope
- **In:**
  - `emit/feature_settings/` and `bricks/feature_settings_*`;
  - specs (`exemplar: true`) and keep markers;
  - a skeleton for new ST modules;
  - lint covering every role, with `dartString` for escaping.
- **No BUILD or `flow_scope`** (ADR-0018). The pubspec carries the root-import packages.
- **Probes** run gen → wire → buildgen. `wire` doesn't route ST yet, so it must only warn.
- **Parallel work:** T-0078 (IX archetype) and T-0079 (wire routing) are running at the same time. Own your `emit/` and `bricks/` subtrees, plus one line in `archetypes.dart`.
- **Out:** behaviour changes.

## Acceptance criteria
- **T-0077-AC1:** both `gen --check` runs exit 0. A one-field change exits 1 and names the file.
- **T-0077-AC2:** both features are unchanged: Bazel and app tests green, and diffs contain only markers, specs and manifests.
- **T-0077-AC3:**
  - Two throwaway ST probes generate, analyse clean and pass BDD under Bazel: a choices page, and an index page.
  - Lint-rejection tests cover every role.
- **T-0077-AC4:**
  - Gates: `test --lockfile_mode=error //...`, lint, format gate, `T-0065-AC5_gates.sh`.
  - Every existing `gen --check`, `wire --check`, `buildgen --check` and `check --all` is clean.
  - Lockfiles unchanged, and every cited test exists.
  - A short finding, with the hand share.

## Log
- 2026-11-28: Created and dispatched (TL), as part of the fourth wave.
