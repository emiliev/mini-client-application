# Verification report — T-0054: `AppFlows` hardening (P-094 to P-098)

- **Verifier:** crew: Verifier, Opus tier (fresh agent, not the implementer)
- **Date:** 2026-11-27
- **Branch / commit verified:** `fleet/T-0054-flow-results-hardening` @ `e68dd7b`
- **Simulator:** `mc-T-0054-verifier-95588`, iPhone 17 Pro, iOS 26.2 (created and deleted by the Verifier through `tool/e2e_ios.sh`; `xcrun simctl list devices` shows no `mc-T-0054-verifier-*` afterwards)
- **Verdict:** **PASS.** Every AC passes on the engineer's tests, on 42 widget probes of my own, and on the device. I found two Minor test gaps (D1, D2). The code is right on both paths (my probes kill the mutants), but the suite does not pin them. Add them to the suite before the async `/me/**` guard lands.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| All AC5 gates | `MC_BAZEL_STARTUP=--output_base=/tmp/mc-ob-T-0054-verifier tool/checks/T-0054-AC5_gates.sh --role verifier` ([gates.md](verifier/gates.md)) | **PASS** on every row: `test //...` (with `//app/...` uncached), lint, `mc_arch_check`, `rules_fork.sh check`, `dart format`, `l10n_check`, fixtures, relative API paths, flow_builder provenance, coverage. 167 tests |
| Lockfile | `test --lockfile_mode=error //...` on `e68dd7b` | **167/167 pass** |
| Coverage, my own parser | [coverage_parser.py.txt](verifier/coverage_parser.py.txt) over each package's own `coverage.dat` (hand-written `lib/` only, `package:` URIs mapped to paths) ([coverage.txt](verifier/coverage.txt)) | mini_client 131/136 = **96.3 %**, app_core 481/500 = **96.2 %**. These match the gate. `app_router.dart` 31/31, `placeholder_pages.dart` 72/72. `flow_results.dart` 117/121: **the misses are lines 369 and 373–375, the body of `superseded()`** (see D1). No `lib/` file is unmeasured except `main.dart` and the barrel |
| Flake check (DoD) | `test --runs_per_test=50 --nocache_test_results` on 11 navigation targets: flow_results_hardening, flow_results, router_observers, not_found, deep_link_back_stack, app, analytics_screens, bdd, links_after_flow, reading_list_route, library_wiring routes ([log](verifier/runs_per_test_50.log)) | **550 runs, 0 failures.** I counted 550 `run_*_of_50` dirs and none has a `test.xml` with failures. None of the new tests drops a storage-writing future |
| L4 E2E | `tool/e2e/prepare_pub_project.sh` into `/tmp/mc-T-0054-verifier-e2e`, then `tool/e2e_ios.sh --task T-0054 --role verifier --runner-cmd "<wrapper> {udid} {target} {driver}"`. The [wrapper](verifier/e2e_run_target.sh.txt) runs `xcrun simctl uninstall <udid> com.emiliev.miniClient` and `rm -rf build/ios/iphonesimulator` before every target ([summary](verifier/e2e/e2e-summary.md)) | **17/17 PASS**: the full suite of 13, plus 4 probe targets of mine. **False-PASS defence (T-0055 not merged):** I grepped all 17 logs for `BUILD FAILED`, `Error (Xcode)`, `Could not build the application`, `Compilation failed` and `Failed to build iOS app`: **0 hits**. Every log has exactly one uninstall line and ends in `All tests passed` |
| Merge check | `git merge --no-commit --no-ff origin/main` (`5f2714d`: T-0052, T-0053, T-0055 docs, journal), `fvm dart pub get --offline`, `test --lockfile_mode=error //...`, then `git merge --abort` | **Merged cleanly** (auto-merge of `app_core/BUILD.bazel`); **178/178 pass**. Reset, and the tree is clean at `e68dd7b` |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0054-AC1 (P-094) | Every call completes exactly once on every path. A guard redirect then `go(from)` gives one completion and no assert. A forgotten `extra` still asserts. V08 is killed | `flow_results_hardening_test` groups `T-0054-AC1` (10) and `T-0054-AC1 review` (10) | **Yes.** The guard is modelled as a real `redirect` plus `refreshListenable`, and sign-in does `go(from)`. Each test checks the exact list of completions (`[null]`, `['l-5']`, `['l-5', null]`), so a second completion would fail it. The listener check (`debugOnChange` reaches no watch after the end) has a live positive control in my VP01. **My probes** ([source](verifier/verifier_probe_test.dart.txt), all 42 pass) cover:<br>• the result; `router.pop` and **system back** (`handlePopRoute`);<br>• a `go` that replaces the page;<br>• a guard redirect then `go(from)`: `[null]`, no assert, and saving the go-built editor adds nothing;<br>• a redirect then system Back;<br>• an **async** guard (50 ms) and a **slow async guard across frames** (400 ms, VP07b/c: not abandoned while the push is still being redirected);<br>• dispose of the app;<br>• `refresh()` ×2 then save gives the id once, and a later Back adds nothing; `refresh()` then Back gives `[null]`;<br>• `refreshListenable` ticks, then save or `go`;<br>• a **restore through JSON**, then save gives the id; a restore then Back gives null;<br>• same-span `push; go` (plain, redirected, async-redirected);<br>• two calls to different flows (top answers first, then the other);<br>• both flows then a `go` (`[null, null]`);<br>• the same flow twice, sequentially and in one span;<br>• two calls with the second redirected, then `replace` / `pushReplacement` of the sign-in page.<br>Every probe ends with "no listener left". **Assert:** a route without `extra: state.extra` throws `…extra: state.extra…`. A correct route reached by push, refresh, `go`, and push without `AppFlows` never trips it (VP22). **V08 killed** (by `a redirected page that pops with a value`) | **PASS** |
| T-0054-AC2 (P-095) | A custom extra pushed and reported: no throw, null after a re-parse, one warning. JSON-safe extras round-trip. A `FlowCall` is never saved | group `T-0054-AC2` (6); T-0049 codec tests unchanged | **Yes.** The widget test pushes `_Picker`, saves twice, and checks no exception, JSON with no trace of the extra, exactly one codec warning and no go_router "complex data type" warning, with go_router's `logger` captured. **My probes:**<br>• VP41: the route sees the custom extra live, **null after `refresh()`** and **null after a JSON restore**, and only one warning across 3 reports;<br>• VP42: a nested JSON-safe map survives refresh plus restore, with no warning;<br>• VP40: nested lists/maps, `List<int>` and `Map<String,int>` round-trip through `jsonEncode`/`jsonDecode`; `-inf`, `[1, NaN]`, `{x: [inf]}`, a `Set` and a `DateTime` are dropped;<br>• VP43: no `FlowCall` in the saved state after a redirect, a `go(from)`, a push or a refresh | **PASS** |
| T-0054-AC3 (P-096) | A result under a dialog, then `go`, gives the result once, in both same-frame orders; the T-0048 and T-0049 overlay tests are unchanged and green | group `T-0054-AC3` (7). `git diff origin/main...e68dd7b -- app/wiring/app_core/test/flow_results_test.dart` is **empty**. No other existing test file except `deep_link_back_stack_test` (P-098) and `analytics_screens_test` (+1 name) changed | **Yes.** **My probes** (VP30–32) cover:<br>• dialog: `go` then pop, pop then `go` (same frame), and `go` alone;<br>• a **bottom sheet** with `go`;<br>• the result held, then `refresh()`, then `go`.<br>Each gives `['c:new-id']` exactly once with no listener left. When the dialog closes on its own, the result is delivered and the route pops to home. Killed: M11, M12 (engineer's), X22 (mine: the stack watch ends with null). X11 (deliver under the overlay) is killed by the T-0048 overlay test | **PASS** |
| T-0054-AC4 (P-097, P-098) | Cold `/nope`, `/a/b/c`, `/comics/abc`, `/nope#frag` each give `[home, not-found]`; Back and Go home each reach home in one action; a running link behaves the same; P-098 goes red under push; URLs unchanged; `not_found` works with analytics | `not_found_test` (21); `deep_link_back_stack_test` `T-0049-AC2 T-0054-AC4 … (/characters/100366)`; e2e `not_found_cold_test`, `not_found_cold_bad_comic_test` | **Yes.** **Device** (4 probe targets of mine, [template](verifier/e2e_probe_template.dart.txt)): each target's cold link gives `matches.length == 2`, the exact text, a back button and Go home. Back (`/a/b/c`, `/comics/abc`) or Go home (`/nope`, `/nope#frag`) reaches home with no back button. Then a **running link to `/nope`** from the characters list gives `[home, not-found]`, and the other action reaches home. **Widget probes** ([source](verifier/verifier_nf_probe_test.dart.txt)): `context.push('/nope')` from inside the app becomes `[home, not-found]`; `/comics/abc`, then a link to `/not-found` itself, does not throw.<br>**Non-parser error paths:** I read go_router 17.5.0 `parser.dart` (pub-cache). `_navigate` hands every error match list to `onParserException` (`parser.dart:192`). That is the only route to a no-match, a throwing redirect and a restore whose root location no longer matches. It is skipped only for an `onEnter` error (`:422–437`, `:483–494`, which call it only when `context.mounted`) and for a disposed router context (`:184–190`, no screen to show). The one other error page is `builder.dart:239`, an **imperative** match whose own location fails. I probed that through a restore (VN01): go_router drops that match and the app shows home, with no ErrorScreen and no exception. So the engineer's claim holds.<br>The `topOnEnter == null` pin **goes red** when an `onEnter` is added (X18, checked with `MUST=` on the pin's name). Even `onEnter: … => const Allow()` also breaks the cold `/nope` tests, so the pin guards something real.<br>**Links as pushes (P1) turn the P-098 test red** (the expected test, by `MUST`). `AppLocations` is unchanged (`git diff` empty) and `not_found_test` pins the URLs. `analytics_screens_test` (T-0053) expects `not_found`, and it passes 50/50 | **PASS** |
| T-0054-AC5 | Gates, coverage, e2e, gate and mutation scripts, F-0049 | See the gates table and Mutations | **Yes.** The mutation script refuses a dirty tree (it refused while my evidence was untracked). It tells BROKEN from KILLED: my first X21 was a compile error and was reported **BROKEN**, not killed, so I rewrote it. It restores and verifies every file. F-0049 gains facts 7–9 and a rule, with no lines removed. TL authorization: the TL-authored AC5 says "Update F-0049 with the new rules", and the task log records it | **PASS** |

## Mutations
[log](verifier/mutations.log). I ran the engineer's script with my mutations appended ([added](verifier/verifier_mutations_added.sh.txt)), with `MC_ROLE=verifier`, on a clean tree. The baseline passed on every run.
- **The engineer's mutations: 11 of 39, all killed.** V08, M01, M05, R1, R2, R3, R5, M11, M12, N01, P1. P1 was killed by the expected T-0054-AC4 test.
- **Mine: 12. Against the engineer's suite, 8 were killed and 4 survived.**
  - **Killed:**
    - X11: deliver under an overlay;
    - X13: every pop value dropped;
    - X21: the listener removed only lazily, on the next change. My first version was BROKEN by a compile error, so I rewrote it;
    - X22: the stack watch ends a held result with null;
    - X16: not-found pushed, not reached by a `go`;
    - X18: an `onEnter` added (the pin went red);
    - X19: not-found Back never pops;
    - X20: the not-found route moved out of home's children.
  - **Survived the engineer's suite:**
    - X02: a push not yet located always counts as superseded;
    - X03: never superseded;
    - X06: first match by any imperative page instead of the push's completer;
    - X01: the page key is not taken on delegate changes, only in the post-frame check.
  - **Against my probes:**
    - X02 is killed by VP07b (the slow async guard);
    - X03 is killed by VP16 (an async guard plus `go` in the same span);
    - X06 is killed by VP23 (`replace` of a redirected page while another call is open);
    - X01 still survives. I judge it equivalent in practice: a re-parse before the first post-frame check re-applies the pending push with the same completer.

## Test-integrity audit
- **Tests deleted, skipped or weakened: none.**
  - `flow_results_test.dart` is byte-identical to `origin/main`.
  - The only removed test lines are in `deep_link_back_stack_test`: the AC2 `testWidgets` is reformatted, with the same body. For `/characters/<id>` only, it no longer opens Characters first. That is the P-098 change, which makes it stronger, and P1 proves it.
  - `analytics_screens_test` gains one expected name.
- **Lint suppressions added:** none (no added `// ignore` or `ignore_for_file` in `git diff origin/main...e68dd7b`).
- **Golden files updated:** none.
- Every AC has tests named `T-0054-ACn` (occurrences of the ID, group names included: AC1 21, AC2 7, AC3 8, AC4 15 in widget tests plus 2 in e2e). AC5 is the gate script.

## Visual acceptance
| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| Cold `/a/b/c` | [v1_cold_abc_back_a_cold.png](verifier/v1_cold_abc_back_a_cold.png) | "Not found" app bar with a back chevron, "Nothing lives at /a/b/c", a red "Go home" button | Yes |
| Cold `/nope#frag` | [v2_cold_frag_gohome_a_cold.png](verifier/v2_cold_frag_gohome_a_cold.png) | The same, with "Nothing lives at /nope#frag" (fragment kept) | Yes |
| Running link `/nope` (from the characters list) | [v4_cold_bad_comic_back_c_running_nope.png](verifier/v4_cold_bad_comic_back_c_running_nope.png) | "Not found" with back chevron, "Nothing lives at /nope", Go home. The test checked 2 matches, so the list is gone | Yes |
| After one Back from cold `/comics/abc` | [v4_cold_bad_comic_back_b_home.png](verifier/v4_cold_bad_comic_back_b_home.png) | "Mini Client" home with **no back chevron**: Characters, New reading list, Search, Open placeholder 7 | Yes |

I looked at the other 12 probe shots, which were not kept. Each `*_a_cold` shows not-found with the right path, a chevron and Go home. Each `*_b_home` and `*_d_home` is home with no chevron. Each `*_c_running_nope` shows "/nope". The suite's own `60`–`62b` checkpoints passed on the device too.

## Issues found
1. **D1 (Minor, test gap; it matters once the `/me/**` guard can be async).** The supersede check is never run by the suite.
   - **Where:** `app/wiring/app_core/lib/src/router/flow_results.dart:369–376` (`superseded()`). Coverage misses 369 and 373–375.
   - **Effect:** mutants X02 (always superseded) and X03 (never superseded) survive the engineer's tests.
   - **Repro:** run X02 with `verifier_probe_test` VP07b (redirect delayed 400 ms). The caller would get null while the sign-in page is still being redirected to.
   - **Correction to the review round:** its claim that "either guard alone is redundant" holds only for **synchronous** redirects. With an async redirect plus a `go` in the same span (VP16), the supersede check is the only thing that ends the call.
   - **Suggestion:** add VP07b and VP16 (async guard) to `flow_results_hardening_test` before the auth guard task.
2. **D2 (Minor, test gap).** The first match by the push's completer is not pinned.
   - **Where:** `flow_results.dart:349`.
   - **Effect:** X06 (match any imperative page) survives the engineer's tests.
   - **Repro:** VP23 opens the editor, signs out, opens the second call (redirected to sign-in), then calls `router.replace('/other')` and Back. Under X06 the second call takes the editor's key and does not end when its page goes.
   - **Suggestion:** add VP23.

## Notes for the Tech Lead
- **Pop value after a re-parse (doc nit, F-0049 fact 7).** A redirected page that pops a value after a `refresh()` gives the caller **null**, not the value (VP21). go_router's re-parse gives the page a fresh completer, and the stack watch ends the call. It still ends exactly once, and the sign-in's `bool` maps to null anyway. F-0049 should say "unless the route state was re-parsed".
- **`replace` keeps the page key** (go_router `parser.dart:284–296`). A call whose redirected page is replaced with `router.replace` ends when the **replacement** leaves (VP23 `replace`: `[]` after replace, `[e:null]` after Back), not at the replace. `pushReplacement` ends it at once. It still ends exactly once.
- **Guard semantics, as specified:** after `go(from)` the original caller gets null, and the editor that the `go` opened has no caller, so its result reaches nobody (F-0049 fact 7). The guard task should decide whether home should re-ask, or whether the guard should `push` instead.
- **Any `onEnter`** (even `Allow()`) breaks cold `/nope` (X18). The pin's message is right: an `onEnter` must route its errors to not-found.
- My simulator is deleted. Probe sources are kept as `.txt`, and the tree is clean at `e68dd7b` (no probe files or BUILD edits).
