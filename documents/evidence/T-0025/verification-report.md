# Verification report — T-0025: `mc_l10n_core` + `mc_formatters` + l10n check

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-24
- **Branch / commit verified:** `fleet/T-0025-l10n` @ **`4ccf962`** (review fixes; verified on `fleet/T-0025-verify2`). Round 1 was `2e6247d` (PASS, on `fleet/T-0025-verify`).
- **Simulator:** none (no UI/e2e scope in this task)
- **Output base:** `/tmp/mc-ob-T-0025-verifier` (via an `MC_BAZELISK` wrapper adding `--output_base`; server shut down at the end)
- **Verdict:** **PASS** (AC4 judged per the TL amendment of 2026-11-24: parity after `dart format`)

## Gates re-run independently (at 4ccf962)
| Gate | Command | Result |
|---|---|---|
| Tests | `tool/bazelw test --nocache_test_results //...` | 43/43 PASS, run twice: before and after `fvm flutter pub get` wrote the generated l10n files into the source tree. Includes the new `//tool/l10n_check:workspace_gate_test`. |
| Lint | `tool/bazelw build --config=lint //...` | PASS (also with the pub-generated files present) |
| Arch | `tool/bazelw run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| l10n | `tool/bazelw run //tool/l10n_check:bin` from the repo root after a build | `l10n_check: OK`, exit 0 |
| Pub lock | `fvm flutter pub get --enforce-lockfile` | PASS |
| Analyze | `fvm flutter analyze` in `utility/mc_l10n_core`, `utility/mc_formatters`, `tool/l10n_check` (and from the root on these 3 paths) | No issues found |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0025-AC1 | `de` → German; `en_XA` → pseudo; en_XA out of release locales (R24) | `//utility/mc_l10n_core:l10n_test` (4 `T-0025-AC1` tests) | Yes: pumps a `MaterialApp` with the delegates and asserts exact German / pseudo strings; asserts `mcSupportedLocales()` excludes `en_XA` (unchanged at 4ccf962; the doc comment now tells apps to use it, not the generated `McL10nCoreL10n.supportedLocales`). Round-1 own probe (temporary, removed): `Text` widgets render `Erneut versuchen` for `de` and `de_AT`, `[Ŕéţŕý ~~]` for `en_XA` with the test locales, and plain `Retry` when `en_XA` is requested against the release `supportedLocales`. | PASS |
| T-0025-AC2 | `Money(1999, EUR)` → `19,99 €` (de), `€19.99` (en) | `//utility/mc_formatters:formatters_test` (`T-0025-AC2 …`, now 5 tests) | Yes: the test literal contains U+00A0 (bytes `c2 a0` checked). Round-1 own probe: de `19,99 €`; en `€19.99`; de_DE/fr same as de; de_CH `€ 19.99`; 0 → `0,00 €`; 5 → `0,05 €`; -1999 → `-19,99 €` / `-€19.99`; 123456789 → `1.234.567,89 €` / `€1,234,567.89`; USD de `19,99 $`; GBP en `£19.99`; JPY 500 de `500 ¥`. New: `formatDateTime` uses `add_jm()`; the test asserts en `11/24/2026 … 3:30 … PM` and de exactly `24.11.2026 15:30`. | PASS |
| T-0025-AC3 | Missing locale / key → check fails naming it | `//tool/l10n_check:l10n_check_test` (7 `T-0025-AC3` tests) + `//tool/l10n_check:workspace_gate_test` | Yes. Own broken tree run through the real binary: exit 1, names each missing locale, missing key, unknown key and wrong `@@locale` (`verifier/AC3_broken_arb_run.txt`). Symlinks: a tree with symlinked dirs pointing at the output base's `external/` (347 `flutter_localizations` ARBs) gives OK; a real-dir copy of one such ARB gives 3 violations (so the probe is sensitive); symlinked ARB *files* are still checked (removing one gives `missing locale de`). Gate: deleting a key from the real `de` ARB makes `workspace_gate_test` fail naming it. Evidence: `verifier/l10n_check_symlinks_and_flags.txt`. | PASS |
| T-0025-AC4 | Rule output == `fvm flutter gen-l10n` (amended: after `dart format`); gates pass | `tool/checks/T-0025-AC4_gen_l10n_parity.sh` + own independent comparison | Script (run by me, with the pub-generated files present in the source package and a `// STALE` line appended to one of them): all 3 files `differs` raw, `identical` after format → PASS, so the stale files were removed before the CLI ran (`verifier/AC4_gen_l10n_parity.md`). Breaking `l10n.yaml` (which Bazel ignores) makes the script FAIL with the CLI's error in the report. Own comparison with a pinned (3.47.7) baseline: after `dart format --language-version=3.13` all 3 byte-identical; raw `_de`/`_en` identical once whitespace is removed, `mc_l10n_core_l10n.dart` identical once whitespace and trailing commas are removed. No content difference. | PASS |

## Review fixes checked (4ccf962)
| Fix | How checked | Result |
|---|---|---|
| `l10n_check` does not follow symlinked dirs; symlinked ARB files still checked | Probe tree above; repo-root runs via `bazel run` and via `bazel-bin/tool/l10n_check/bin` with cwd = root (bazel-* links and `.dart_tool` present) | OK, no false `flutter_localizations` violations |
| Parity script pins Flutter, removes stale files, fails on a `gen-l10n` error | `.fvmrc` pin extracts `3.47.7`; fvm's global is **3.47.8**, so the pin matters (the script would fail the `grep "Flutter 3.47.7"` without it). Stale-file and CLI-error runs above. | OK |
| IDE / pub path | `flutter: generate: true`; `fvm flutter pub get` writes the 3 files beside the ARBs, all gitignored (`git status --ignored`); `fvm flutter analyze` clean; `bazel query labels(srcs, …:mc_l10n_core)` = `:_l10n` + the 2 hand-written files only; test and lint with the files present pass (no clash) | OK |
| `formatDateTime` follows the hour cycle | Test above; mutation `add_jm` → `add_Hm` makes it fail (`Actual: '11/24/2026 15:30'`), reverted | OK |
| `mcSupportedLocales()` excludes `en_XA` | `T-0025-AC1 release locales exclude the pseudo-locale (R24)` passes; doc comment added | OK |
| `workspace_gate_test` fails on a broken ARB | Mutation above, reverted | OK |
| CLI flags | `--locales=en,de,fr`, `--locales X`, `--locales` / `--locales=` (exit 2), unknown flag (exit 2) | OK |
| Keyed by package path | Unit test `same-named packages in different folders are separate`; code keys by `file.parent×4.path` | OK |
| Narrower `.gitignore` | `git check-ignore`: `mc_l10n_core_l10n.dart`, `…_l10n_de.dart` ignored; `foo_l10nx.dart`, `l10n_utils.dart`, `lib/l10n/x_l10n.dart` not ignored | OK (see issue 3) |

## Mutation checks (all reverted)
- Round 1: `Abbrechen` → `Abbrechenn` fails `T-0025-AC1 de …`; `simpleCurrency` → `currency` fails all three money tests.
- Round 2: drop `errorServer` from the `de` ARB fails `workspace_gate_test`; `add_jm` → `add_Hm` fails the date-time test; broken `l10n.yaml` fails the parity script.

## Test-integrity audit
- Tests deleted, skipped or weakened: none (4ccf962 adds 3 `l10n_check` tests, 1 formatter test and `workspace_gate_test`; nothing removed).
- Lint suppressions added: none (`ignore:` / `skip:` grep over the diff is empty).
- Golden files updated: none.

## Hygiene
- Generated l10n not committed; `.gitignore` matches the generated names (see above); `git ls-files` has no generated file.
- Root changes are exactly the listed four: `.gitignore`, `pubspec.yaml` (3 workspace members), `pubspec.lock` (+`intl` 0.20.3, +`flutter_localizations`), `MODULE.bazel.lock`. 4ccf962 changes only `.gitignore` among them.
- `MODULE.bazel.lock` (unchanged since 2e6247d): the only removal is the `pubspec.lock` digest (new `453cc21…` = `shasum -a 256 pubspec.lock`); additions are the hub repos `pub_deps__intl` / `pub_deps__flutter_localizations` and those two names in the existing repos' `lock_packages`. Explained by the two new pub deps (F-0023 §7); `--lockfile_mode=error` passes.
- The finding was renumbered F-0022 → F-0023 in 4ccf962; the TL amendment and round-1 report referred to F-0022.

## Issues found
None blocking. Minor, for pending work:
1. (minor, R24 risk) The generated `McL10nCoreL10n.supportedLocales` is still public and lists `en_XA`; only a doc comment steers apps to `mcSupportedLocales()`. An arch-check / lint ban outside tests would enforce R24.
2. (minor) `workspace_gate_test` covers only the `arbs` filegroups listed in its `data`; a new package with ARBs that is not added there is skipped silently. The binary run covers the whole tree but is not a gate.
3. (nit) Bazel's `srcs` exclude (`lib/src/l10n/*_l10n*.dart`) is broader than `.gitignore` (`*_l10n.dart`, `*_l10n_[a-z]*.dart`): a committed hand-written `lib/src/l10n/foo_l10nx.dart` would be tracked but left out of the Bazel build. `*_l10n_[a-z]*.dart` also still ignores names such as `foo_l10n_helpers.dart`.
4. (nit) Violations print only the directory's basename, so two same-named packages in different folders give identical-looking lines.
5. (nit) Repo-wide `fvm flutter analyze` at the root reports ~275k issues (e.g. `tool/loc/test`, `mc_fixtures_characters/tool`, the bazel-* trees); none come from T-0025's packages, which are clean. Already the case before this task.
6. (nit, round 1) The AC2 test literal's U+00A0 is invisible; ` ` would read better. `Money.majorUnits` is a `double`, exact up to 2^53 minor units.

## Notes for the Tech Lead
- AC4 passes only under your amendment; the raw output is not byte-identical (F-0023, upstream P-046).
- Correction to round 1: there I wrote that the CLI baseline was 3.47.7. Without a `.fvmrc` in the throwaway copy, fvm used its global **3.47.8**; the round-2 pin fixes this, and the result (identical after format) is the same with 3.47.7.
- Probe tests and fixtures were temporary (scratchpad / reverted). Only this report and the `verifier/` evidence are committed.
