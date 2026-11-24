# Verification report — T-0025: `mc_l10n_core` + `mc_formatters` + l10n check

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-24
- **Branch / commit verified:** `fleet/T-0025-l10n` @ `2e6247d` (verified on `fleet/T-0025-verify`)
- **Simulator:** none (no UI/e2e scope in this task)
- **Output base:** `/tmp/mc-ob-T-0025-verifier` (via an `MC_BAZELISK` wrapper adding `--output_base`; server shut down at the end)
- **Verdict:** **PASS** (AC4 judged per the TL amendment of 2026-11-24: parity after `dart format`)

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| Tests | `tool/bazelw test --nocache_test_results //...` | 42/42 PASS (includes `//utility/mc_l10n_core:l10n_test`, `//utility/mc_formatters:formatters_test`, `//tool/l10n_check:l10n_check_test`) |
| Lint | `tool/bazelw build --config=lint //...` | PASS |
| Arch | `tool/bazelw run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| l10n | `tool/bazelw run //tool/l10n_check:bin` (repo-wide) | `l10n_check: OK` |
| Lockfile | `tool/bazelw build --lockfile_mode=error //...` | PASS; working tree clean after every run |
| Pub lock | `fvm flutter pub get --enforce-lockfile` | PASS |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0025-AC1 | `de` → German; `en_XA` → pseudo; en_XA out of release locales (R24) | `//utility/mc_l10n_core:l10n_test` (4 `T-0025-AC1` tests) | Yes: pumps a `MaterialApp` with the delegates and asserts exact German / pseudo strings; asserts `mcSupportedLocales()` excludes `en_XA`. Own probe (temporary, removed): `Text` widgets render `Erneut versuchen` for `de` and `de_AT`, `[Ŕéţŕý ~~]` for `en_XA` with test locales, and plain `Retry` when `en_XA` is requested against release `supportedLocales`. | PASS |
| T-0025-AC2 | `Money(1999, EUR)` → `19,99 €` (de), `€19.99` (en) | `//utility/mc_formatters:formatters_test` (`T-0025-AC2 …`) | Yes: the test literal contains U+00A0 (bytes `c2 a0` checked). Own probe: de `19,99 €`; en `€19.99`; de_DE/fr same as de; de_CH `€ 19.99`; 0 → `0,00 €`; 5 → `0,05 €`; -1999 → `-19,99 €` / `-€19.99`; 123456789 → `1.234.567,89 €` / `€1,234,567.89`; USD de `19,99 $`; GBP en `£19.99`; JPY 500 de `500 ¥`. All correct. | PASS |
| T-0025-AC3 | Missing locale / key → check fails naming it | `//tool/l10n_check:l10n_check_test` (4 `T-0025-AC3` tests) | Yes. Own broken tree (`feature/` and `utility/`, 4 packages) run through the real binary: exit 1, names `f_nolocale: missing locale de`, `f_nokey: locale de is missing key bye`, `f_nokey: locale en_XA is missing key hello`, `u_badloc: locale de has unknown key b`, wrong `@@locale`; `--locales en,de,fr` adds `missing locale fr` per package. Evidence: `verifier/AC3_broken_arb_run.txt`. | PASS |
| T-0025-AC4 | Rule output == `fvm flutter gen-l10n` (amended: after `dart format`); gates pass | `tool/checks/T-0025-AC4_gen_l10n_parity.sh` + own independent comparison | Script run by me: all 3 files `differs` raw, `identical` after format → PASS (`verifier/AC4_gen_l10n_parity.md`). Own comparison (CLI 3.47.7 in a throwaway copy, exit 0; Bazel output from my output base): after `dart format --language-version=3.13` all 3 byte-identical; raw `_de`/`_en` identical once whitespace is removed, `mc_l10n_core_l10n.dart` identical once whitespace and trailing commas are removed (one trailing comma in `supportedLocales`; `dart format` adds it). No content difference. Gates: see above. | PASS |

## Mutation checks (reverted)
- `mc_l10n_core_de.arb`: `Abbrechen` → `Abbrechenn` → `T-0025-AC1 de resolves the common strings in German` FAILS.
- `formatters.dart`: `NumberFormat.simpleCurrency(` → `NumberFormat.currency(` → all three `T-0025-AC2` money tests FAIL (`19,99 EUR`, `EUR19.99`, `JPY500`).
- Both reverted with `git checkout`; tree clean.

## Test-integrity audit
- Tests deleted, skipped or weakened: none (diff is 26 added + 5 modified files; no existing test touched).
- Lint suppressions added: none (`ignore:` / `skip:` grep over the diff is empty).
- Golden files updated: none.

## Hygiene
- Generated l10n not committed: `.gitignore` adds `**/lib/src/l10n/*_l10n*.dart`; `git check-ignore` confirms it matches the generated names; `git ls-files` has no generated file.
- Root changes are exactly the listed four: `.gitignore`, `pubspec.yaml` (3 workspace members), `pubspec.lock` (+`intl` 0.20.3, +`flutter_localizations`), `MODULE.bazel.lock`.
- `MODULE.bazel.lock`: 2 lines removed / ~340 added. The only removal is the `pubspec.lock` file digest (new digest `453cc21…` = `shasum -a 256 pubspec.lock`). Additions are the two new hub repos `pub_deps__intl` / `pub_deps__flutter_localizations` and `intl` / `flutter_localizations` added to the existing repos' `lock_packages` lists. Fully explained by the two new pub deps (F-0022 §7); `--lockfile_mode=error` passes.
- Crew file rules respected: only own task file, new finding F-0022, new evidence and check script.

## Issues found
None blocking. Minor, for pending work:
1. (minor, R24 risk) The generated `McL10nCoreL10n.supportedLocales` (and `McL10nCoreL10n.localizationsDelegates`) is exported publicly and includes `en_XA`; its own doc comment suggests `supportedLocales: McL10nCoreL10n.supportedLocales`. The release filter only holds if callers use `mcSupportedLocales()`. Suggest an arch-check / lint rule (or P5 C10) banning `McL10nCoreL10n.supportedLocales` outside tests.
2. (minor) The parity script ignores the `fvm flutter gen-l10n` exit code and `cp -R`s the package including any stale (gitignored) generated files; in a dirty checkout a failed CLI run could compare stale files and pass falsely. Suggest checking the exit code and copying only ARBs, `l10n.yaml` and `pubspec.yaml`.
3. (minor) `l10n_check` is not wired into any gate script; it runs only when invoked. It also scans only `lib/src/l10n/`, so ARBs placed elsewhere are skipped without a warning.
4. (nit) The AC2 test literal contains an invisible U+00A0; `'19,99 €'` would be clearer to readers.
5. (nit) `Money.majorUnits` divides into a `double`; exact for display up to 2^53 minor units, fine for now.

## Notes for the Tech Lead
- AC4 passes only under your amendment; the raw output is not byte-identical (F-0022, upstream P-046).
- My probe tests and fixtures were temporary (scratchpad / reverted); only this report and `verifier/` evidence are committed.
