# Verification report: T-0020: `mc_config`, `mc_monitoring`, `mc_event_bus`, `mc_storage`

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-23
- **Branch / commit verified:** `fleet/T-0020-core-utils` @ **`320730c`**, which is the review fixes `647948a` plus `320730c`, rebased onto main `8edca7f`. I checked it out as `fleet/T-0020-verify2`. I first verified the original commit `19c216d` (on `fleet/T-0020-verify`, report `23a06fd`). This report replaces that one.
- **Simulator:** none. This is a pure-Dart utility task with no UI and no e2e.
- **Bazel:** `tool/bazelw --output_base=<verifier scratch>`, a private output base, shut down at the end.
- **Verdict:** **PASS**. Every AC passes. The medium issue from the first pass (event bus re-entrancy) is fixed. Three low issues remain, listed below.

## Gates re-run independently (at `320730c`)
| Gate | Command | Result |
|---|---|---|
| All tests | `tool/bazelw test --nocache_test_results //...` | **27/27 PASS**. This includes the T-0018 and T-0019 targets that came in with the rebase. |
| Analyze + format | `tool/bazelw build --config=lint //...` | OK |
| Architecture | `tool/bazelw run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| AC1 per env | `tool/bazelw test --nocache_test_results --//tool/bazel/config:env={e2e,dev} //utility/mc_config:all` | 2/2 PASS for each env |
| Outside Bazel | `fvm dart test test/bundled_config_test.dart` (run in `utility/mc_config`) | `All tests skipped.` with the message "Needs the Bazel-bundled config". The skip can't hide a failure under Bazel: the `env` select has one branch per flag value and no default, so the variables are always set there. |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0020-AC1 | `env=e2e` gives latency 0, `env=dev` gives the dev values, no `--dart-define` | `mc_config:bundled_config_test`, `mc_config:app_config_test` | Yes. **First pass:** I inspected the built `app_config.json`: the default gave `latencyMs 250` and `e2e` gave `latencyMs 0`. `aquery` over `deps(bundled_config_test) ∪ deps(mc_config) ∪ deps(app_config)` showed 0 `--dart-define` for both e2e and dev. **This pass:** I repeated the negative check (set e2e `latencyMs` to 5) and the test FAILED with `Actual 0:00:00.005000`, then I reverted it. The config sources are unchanged since `19c216d`. The only change is the skip outside Bazel. | PASS |
| T-0020-AC2 | The in-memory sink holds `log`, `trackEvent` and `recordError` in order, with levels and attributes | `mc_monitoring:monitoring_test` (3 tests, one of them the new throwing-sink test) | Yes. **My own checks:** I ran three throwing sinks (first, middle and last) around a console sink and an in-memory sink, with an error and an attribute whose `toString` throws. Nothing threw, and the in-memory sink held `[LogEntry, ErrorEntry, EventEntry]` in order. From the first pass: interleaved order across two sinks, the attribute map is copied, the entries can't be modified, and the DI initializer works. | PASS |
| T-0020-AC3 | Two `favourites` subscribers each get the event once; an unsubscribed listener gets nothing | `mc_event_bus:event_bus_test` (4 tests: the 2 original, plus re-entrant publish and publish after dispose) | Yes. **My own checks:** a cascade, where the `a` listener publishes `b` and `c`, runs inside `runZonedGuarded` with no zone errors and delivers `[a, b, c]` in order. That closes the earlier medium issue. Delivery is now async, so I also cancelled a listener *after* publish but *before* the microtask delivery: it got nothing, and the other two got 1 each. Publish after dispose doesn't throw and delivers nothing. | PASS |
| T-0020-AC4 | Write, then a new store on the same directory reads it back; a corrupt file gives a typed `Result` failure | `mc_storage:file_store_test` (9 tests) | Yes. **My own checks:** file names are lowercase hex (`4b6579.json` for `Key`, `6b6579.json` for `key`), so keys differing in case get separate files on case-insensitive APFS. A new store reads all keys back. I ran 30 overlapping writes interleaved with reads from new instances, on 200 KB values: every read was either a whole value or a success, the last write won, and no `.tmp` files were left. In 100 rounds of read, delete and read racing on one key, the reads never failed. A directory at the key's path gives a typed `StorageFailure` for read, write and delete. Truncated JSON, invalid UTF-8 and an empty file give typed failures. Two edge cases are in Issues 1 and 2. | PASS |
| T-0020-AC5 | The three packages import no Flutter; tests, lint and arch check are green | `*:no_flutter_test` x3, plus the gates | Yes. The regex now covers `(import\|export)`. **Negative check:** I added `lib/src/zz_vfy.dart` containing `export 'package:flutter/foundation.dart';` and `mc_storage:no_flutter_test` FAILED, naming the file. Then I removed it. From the first pass: no `flutter` or `dart:ui` text in any of the 4 packages or their deps, and the `dart_library` closure is only `mc_di`, `mc_prelude`, `get_it`, `async`, `collection` and `meta`. | PASS |

## Review fixes (requested checks)
| Check | Result |
|---|---|
| Event bus: a listener can publish from inside its callback | Fixed. The controller is now an async broadcast controller. Covered by a new test and by my cascade check. |
| Event bus: publish after dispose is a no-op | Fixed. There's an `isClosed` guard, covered by a test and by my check. |
| Monitoring: a throwing sink doesn't block later sinks, and monitoring never throws | Fixed. Each sink call is wrapped in `try`/`on Object`. Covered by a test and by my check, which includes `toString` throwing inside the console sink. |
| Storage: atomic writes (temp file plus rename) | Yes. The value is written to `<hex>.json.<n>.tmp` with `flush: true`, then renamed. Writes and deletes of one key are serialised **per `FileStore` instance**. |
| Storage: concurrent writes stay whole | Yes, within one instance (see Issue 1 for two instances). |
| Storage: a read racing a delete returns null | Yes. `PathNotFoundException` maps to `success(null)`. |
| Storage: keys differing only in case don't collide | Yes (hex names). |
| Storage: a directory at the key path gives a typed failure | Yes, for read, write and delete. |
| `no_flutter_test` catches `export` | Yes (negative check above). |
| `bundled_config_test` skips outside Bazel | Yes. |

## Hygiene
- Relative to main `8edca7f`, the only root change is `pubspec.yaml` (+4 workspace entries). Everything else is under the 4 packages, `tool/bazel/config/` or `documents/`. Nothing generated is committed.
- Test integrity: no tests were deleted or skipped under Bazel. The original corrupt-file test now corrupts the hex-named file the store wrote, which is the same assertion. Its value literal was simplified, but the assertions are not weakened. No lint suppressions. My temporary `vfy_test` targets and the mutations were reverted. Running `fvm dart test` created only git-ignored `.dart_tool/` folders.

## Issues found
1. **(low) Two `FileStore` instances on one directory, writing one key concurrently, lose writes.** The temp-file counter is per instance, so both instances use `<hex>.json.0.tmp`, `.1.tmp` and so on, and one instance's rename fails. In my run, 10 of 20 writes returned `StorageFailure`. The file left behind was whole, and no temp files remained. Normal use is safe because DI registers one singleton. Suggested fix: give the temp name a unique suffix (for example pid plus a random value or microseconds), or document "one store per directory".
2. **(low) Keys longer than about 123 UTF-8 bytes fail with a typed `StorageFailure` (`File name too long`, errno 63).** Hex doubles the length, and the `.json.<n>.tmp` suffix is added on top. It doesn't crash, but the limit should be documented, or long keys should be hashed.
3. **(low, carried over) Catalogue gaps:** `Monitoring.setKey` (U05) and the store abstraction with an in-memory implementation (U11) are not in T-0020's scope. They belong in `pending-work.md`.

## Notes for the Tech Lead
- AC1's consuming target is a test until the app bundles `//tool/bazel/config:app_config`. Re-run the aquery count check on the app target when that happens.
- Issues 1 and 2 can be follow-ups. None of them blocks merging.
