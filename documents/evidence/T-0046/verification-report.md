# Verification report: T-0046 `discovery_search` exemplar (SR), `discovery_wiring`, P1-19

- **Verifier:** crew: Verifier, Opus tier (a fresh agent; not the implementer). The single pass after `/code-review` (ADR-0011).
- **Date:** 2026-11-27
- **Branch / commit verified:** `fleet/T-0046-discovery-search` @ **`bdd0888`**, a detached checkout in the Verifier's own worktree (merge base with `origin/main`: `1d9bde1`)
- **Simulator:** `mc-T-0046-verifier-70220` (iPhone 17 Pro, iOS 26.2), created and deleted by `tool/e2e_ios.sh` (`SIMULATOR_DELETED_AT=1795737056`; `xcrun simctl list devices | grep -c mc-T-0046-verifier` → `0`). No shared simulator was touched.
- **Bazel:** `tool/bazelw --output_base=/tmp/mc-ob-T-0046-verifier`; tests run with `--nocache_test_results`; the server was shut down at the end. Scratch work in `<scratchpad>/T-0046-verifier/` and `/tmp/mc-T-0046-verifier-*`.
- **Verdict: PASS.** Every AC passes on my own runs. Six Low findings (four test gaps, one UX gap, one stale comment), none of them blocking. They are listed under "Issues found" so that the bricks can decide whether to copy them.

My evidence is in [`verifier/`](verifier/). Links are relative to this file.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| All gates (AC8) | `MC_BAZEL_STARTUP=--output_base=/tmp/mc-ob-T-0046-verifier MC_COVERAGE_EXEMPT=app/wiring/app_core tool/checks/T-0046-AC8_gates.sh --role verifier` | **PASS**, every row ([gates.md](verifier/gates.md)): `test //...` (touched packages uncached), lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, fixtures check, relative paths, byte identity, cutoff, not committed, gen-l10n parity, coverage. `app_core` 85.3 % exempt (accepted, P-088) |
| Every test, uncached | `test --nocache_test_results //...` | **Executed 134 out of 134 tests: 134 tests pass.** This includes every comics_details and characters_list target, which use the changed shared storage steps, all `mc_paging` targets, `mc_test_steps` and `l10n_check`. `:bdd_test` has 44 test cases, 0 failed, 0 skipped |
| Byte identity, my own build_runner run | `T-0046-AC7_matches_build_runner.sh --role verifier` | **11 of 11 EQUAL**; nothing missing or extra ([byte_identity.md](verifier/byte_identity.md)). build_runner really ran in a fresh overlay (`wrote 8 outputs`, then `wrote 5 outputs`) |
| Coverage, my own parser | `bazel coverage --nocache_test_results` over the feature, the wiring and `mc_paging`, then my own LCOV union ([coverage.txt](verifier/coverage.txt)). It maps `package:` URIs, unions DA lines over every target and both test configurations, and drops `.g/.freezed/.config` and gen-l10n files | discovery_search **333/333**, discovery_wiring **22/22**, `mc_paging` **129/129** (`debounced_query.dart` 32/32) = 100 %. The files that appear in no report are declaration-only: the barrels, the abstract API and navigator, `flow_scope.dart`, the freezed state and flow state, `route_targets.dart`. These equal the engineer's figures. Note: `mc_paging`'s `dart_test` targets write LCOV under the `darwin_arm64-fastbuild-ST-…` testlogs, not under `bazel-testlogs` |
| `tool/ide_sync` safety | `tool/ide_sync --env dev` (`copied=45`, `git status` unchanged), then `T-0042-AC4_safety.sh --role verifier`, then `tool/ide_sync --clean` (`cleaned=81`) | **PASS** ([t0042_ac4_safety.md](verifier/t0042_ac4_safety.md)): the synced tree ran 0 actions and "Executed 0 out of 134 tests", 46,219 outputs had the same bytes, and all 4 negative controls PASS. `fvm flutter analyze` over the 6 touched packages on the synced tree: no issues. Every `lib/**` glob of the feature and the wiring excludes `MC_GENERATED_DART` |
| `mc_paging` unchanged | `git diff origin/main...HEAD -- utility/mc_paging` | Only `submit` was added (28 lines) and 5 new tests were appended. No earlier test line changed |
| L4 E2E | `tool/e2e/prepare_pub_project.sh --app app/mini_client --out /tmp/mc-T-0046-verifier-e2e`, then `tool/e2e_ios.sh --task T-0046 --role verifier` with all 7 app targets plus my probe target | **8 of 8 PASS** ([e2e-summary](verifier/e2e/e2e-summary.md)): `search_journey` 35 s, `search_deeplink` 28 s, my `zz_verifier_search_probe` 33 s ([source](verifier/e2e/zz_verifier_search_probe_test.dart.txt)), and the T-0033/T-0041 journeys and links (regressions: home gained a button). The probe existed only in the scratch copy |

## Acceptance criteria
| AC | Mapped test(s) / checkpoint | Does the test really assert the AC? | Result |
|---|---|---|---|
| T-0046-AC1 | `:bdd_test` "Typing a name shows its characters, then its comics…", the type-chip, "Show more", sticky-chip and one-type scenarios; `:contract_test` AC1 ×2; goldens | **Yes.** `expectSectionShows` takes the first *n* entries of `mc_fixtures_discovery`'s own `SearchIndex` ranking, checks the fixture has *n*, and compares the shown row ids **exactly** (not a prefix), then the title, subtitle and decoded bundled art of each row. `shownResults` scrolls the whole lazy list, so it never passes on an empty tree. Section order comes from header positions, and every character row must sit above every comic row. The chip scenario asserts 1 request after three chip changes, so filtering is client-side. The ranking itself is pinned independently by the fixture package's `ranking_test` and snapshots (T-0043) and by the contract test's `Spindle Alchemist` / `Spindle Chronicles #1`. Killed: AC1-a (reverse hits) in my re-run; the engineer's AC1-b…i | **PASS** |
| T-0046-AC2 | Failure outline ×4 with Retry; "A double Retry sends one request"; nothing found; under 2 characters; shortening; the folded too-short outline ×3; the fixture-set scenarios; `:contract_test` AC2 ×6 | **Yes.** Retry recovers with the same query: my **V05** (Retry upper-cases the query, so the case-insensitive results look identical) is killed by the `q=spi` request count. A double Retry sends one request (AC2-d killed). Empty shows the empty state with no Retry. `s` and ` s ` send 0 requests; `sp` sends 1. The backend's `400 query_too_short` for `e`+U+0301 and two U+0301 (1 request each) shows the recent searches, no failure and no Retry, and `no error was reported`. That step is not vacuous: my **V27b** (the too-short branch reports an error) is killed. Any other 400 stays `ApiClientError`: my **V10** (any coded 400 counts as too short) is killed by the contract test. R5-b killed | **PASS** |
| T-0046-AC3 | BDD character/comic taps (`called(1)` + `verifyNoMoreInteractions`), the double tap and the re-open; `routes_test` AC3 ×2 (push, then Back to the search); `mini_client:search_route_test` AC3 | **Yes**, for "exactly once". Killed: AC3-d (`go` instead of `push`), R8-a (no guard), my **V40** (character sent to the comic location). The 500 ms value of the guard is not pinned (Issue 1) | **PASS** |
| T-0046-AC4 | German: field, hint, chips, sections with counts, `20 zeigen`, `20 von 152 angezeigt`, the empty section, nothing found, the error and Retry, the recent searches, the failed Clear. `en_XA`: every state with `nothing overflows` | **Yes.** The strings are exact. `nothing overflows` reads the tester's pending exception. The l10n gate test names a planted missing German key. Engineer's AC4-a/b/c killed (not re-run) | **PASS** |
| T-0046-AC5 | e2e journey and deep link on my simulator; my probe (blank `?q=` link, then the real Back button); `routes_test` AC5 ×8; `search_route_test` AC5 ×3; BDD linked query (at once) and blank query | **Yes.** All screenshots looked at (below). Home → Search → "spi" → grouped → Comics chip → comic page → back → results → clear → recent "spi". `miniclient://app/search?q=spi` as the start link: no home, field `spi`, grouped results; a second link opens `amber` over it. **Back to the results** (my probe taps the comic page's real `BackButton`, not `router.pop()`): the results are still there, still filtered by Comics, and the field still reads `spi`. **`?q=` blank** start link: the field is empty and focused, no results, the hint shows. Killed: AC5-b, R10, my **V18** (always autofocus), **V26** (flow not keyed by query) | **PASS** |
| T-0046-AC6 | `discovery_search_typing.feature` (15 scenarios under fake time, held and released per query); `mc_paging:debounced_query_test` AC6 ×5 | **Yes**, see "AC6 in detail" | **PASS** |
| T-0046-AC7 | `:architecture_test` (barrel exactly `DiscoverySearchFlow`, `DiscoverySearchNavigator`, `CharacterId`, `ComicId`, each with `show`; R15 on every generator-read file); `mc_arch_check` OK; `:flow_scope_test` AC7 ×3; `:contract_test` AC7 ×6; byte identity 11/11 (mine); cutoff, not committed and gen-l10n parity (in my gates run); fixtures check; `MC_GENERATED_DART` + safety (mine) | **Yes** | **PASS** |
| T-0046-AC8 | My gates run, my coverage, traceability | **Yes.** JUnit names carrying the ID across all `test.xml` of my runs: AC1 19, AC2 21, AC3 7, AC4 6, AC5 16, AC6 22, AC7 14, AC8 1 (the l10n gate test), plus the 2 e2e targets | **PASS** |

### AC6 in detail (the core)
| Race / rule | Scenario | Proof it bites |
|---|---|---|
| One request for "spi" typed fast | "Typing one character at a time…": `s`, `sp`, `spi` 100 ms apart, then 0 requests; 299 ms → 0; +1 ms → exactly 1, `q=spi` | AC6-a (no debounce) and AC6-b (200 ms) killed by the engineer; my **V30** (301 ms) and **V31** (a keystroke does not cancel the pending timer) killed. So the boundary is pinned from both sides |
| A slow answer for an old query after the new one | `spire` held and sent, `spin` answered, `spire` released: still `spin`'s five characters by id, `Spire Alchemist` absent, field `spin`, 2 requests | AC6-c killed (my re-run) |
| Reverse order | Both held, `spin` released first, then `spire` | Same guard as AC6-c |
| Clearing while in flight | `spi` held and sent, the field's clear button tapped → recent searches `amber`; release → still `amber` (not saved), no stale row, field empty | AC6-d killed (my re-run); AC6-e killed by the engineer |
| Shortening while in flight | `spi` held, `s` typed, release → the hint shows, 1 request | AC6-f killed (my re-run) |
| `submit` for a tapped recent search | After a zero-time frame the request is already out (2 for `amber`), the field reads `amber`; after +300 ms still 2 | AC6-l killed (my re-run); my **V19** (the field not filled) killed |
| `submit` for a linked query | "A search opened with a query searches it at once": 1 request after one zero-time frame, field `spi` and not focused, still 1 after it settles | AC6-l2 and AC5-b killed |
| History: most recent first, no repeats, cap 10, found-only | 13 searches, `zzzz` (nothing found) placed late and `spi` repeated → exactly the 10 expected, in order | AC6-i, AC6-n killed by the engineer |
| Survives a new flow | "The recent searches survive a new search flow" (a new flow instance over the same storage) | AC6-o killed by the engineer |
| A failed save keeps the stored list (slow load, linked search, unwritable storage, clear) | "A save that fails while the stored searches are still being read keeps them" | AC6-m killed (my re-run) |
| A clear during an in-flight save wins | "Clearing the recent searches while a search is being saved…" | AC6-j killed (my re-run) |
| A failed Clear restores the list and says so | "A Clear that fails keeps the recent searches and says so", plus its German twin; the next flow still has them | R7-a killed (my re-run); R7-b killed by the engineer; my **V03** (Clear empties only after storage answers) killed |
| `DebouncedQuery.submit` (solitary) | 5 tests: fires at once and cancels a pending search; dedup against the last query; a later `update` of the same text does not search; a blank submit clears only after a search; nothing after `dispose` | R3-c killed (my re-run). My **V14** survives (Issue 3) |

Guards with no killing test: the initial-load version check (**V01**, documented by the engineer as unreachable in practice; I agree) and the failed-Clear version check (**V02**, Issue 2).

### The shared storage steps
- **`the app can no longer write to storage`** keeps reads working. My probe P1 ([feature](verifier/probes/zz_verifier_probe.feature), [run](verifier/probes/probe_run.txt)) shows:
  - the session directory is a link to `mc_storage_ro_*`;
  - the stored file is copied and readable, and contains `amber`;
  - a create and a rename both throw `FileSystemException`;
  - a new flow then reads `amber`.
- **It cleans up after itself.**
  - Under Bazel, `Directory.systemTemp` is the user's real `$TMPDIR`, so a leak would persist.
  - My probe P2 runs right after P1 in the same process. It finds **no** `mc_storage_ro_*` entry and no link in `$TMPDIR`.
  - After the whole BDD suite, which contains 4 unwritable-storage scenarios, `ls $TMPDIR | grep -c '^mc_storage_ro_'` is **0**.
  - The session's `_finish` deletes only the link, and the step's tear-down makes the copy writable again and removes it.
- **The step is not vacuous.**
  - My **V32** (no `chmod`, so storage stays writable) is killed.
  - My **V32b** (nothing copied, so reads fail too, as in the first version) is killed.
- **`mcFinishStorageIo`** matters: my **V34** (stop after the 10 fixed rounds) is killed.
- **Every other user still passes**, uncached: comics_details (`the app finishes writing to storage`, 5 targets) and characters_list (5 targets). "Can no longer write" has no user outside discovery_search yet.

## Test-integrity audit
- **Tests deleted, skipped or weakened:** none on `main`. `git diff origin/main...HEAD` changes these existing test files, all of them additive:
  - `boot_test`: +2 tests.
  - `workspace_gate_test`: +1 test.
  - `debounced_query_test`: +5 tests appended; nothing earlier changed.
  - the shared step `the app finishes writing to storage`: the same 10 rounds, then more until the directory is stable, so it is stricter.

  The review round's removals exist only on this branch: the suggestions contract test went together with the API method and `SuggestionsDto`, and nothing else was removed with it. The other `-` lines between `8cdab4f` and `HEAD` are the "See all" labels, renamed to "Show 20" and "Characters (152)", and the two "searched once typing would have paused" scenarios. Those became stricter "at once" scenarios: 0 ms instead of 300 ms, with no second request.
- **Lint suppressions added:** none (no `// ignore`, `ignore_for_file`, `skip:` or `solo:` in the diff).
- **Golden files:** 5 new ones (`search_recent`, `search_results_all`, `search_results_comics`, `search_empty`, `search_error`). I looked at all 5: the caret is steady, the counts are in the titles, and "Show 20" is not ellipsised. No existing golden changed.
- **Mutations:** **29 of 35 killed** by a failing test, none by a compile error ([script](verifier/mutations.sh), [log](verifier/mutations.log)). The baseline passed on 9 targets first; every file was restored and verified, and `git status` was clean afterwards.
  - **Engineer's, re-run: 15 of 15 killed.** AC1-a, AC2-d, AC3-d, AC5-b, AC6-c, AC6-d, AC6-f, AC6-j, AC6-l, AC6-m, R3-c, R5-b, R7-a, R8-a, R10.
  - **Mine: 14 of 20 killed.** V03, V05, V10, V18, V19, V26, V27b, V30, V31, V32, V32b, V34, V35, V40.
  - **Mine, survived:** V01 (equivalent in practice), V02, V11, V11b, V14, V27 (Issues 1 to 4).

## Visual acceptance
| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| Grouped results for "spi" (AC1, AC5) | [32_search_results_grouped.png](verifier/e2e/32_search_results_grouped.png) | Back arrow, "Search", the field reads `spi` with a clear ×, the chips All (selected), Characters, Comics. "Characters (152)" with "Show 20" (whole), 5 characters Spindle Alchemist…Captain, each with art and team. "Comics (400)" with "Show 20", Spindle Chronicles #1, #10 (2020) | yes |
| A comic from the search (AC5) | [34_comic_from_search.png](verifier/e2e/34_comic_from_search.png) | "Spindle Chronicles #1" page with Back: cover, Issue #1, Add to favourites, Synopsis, Details (`$5.99`, 56 pages, Jan 12, 2020), Creators | yes |
| Blank-query start link `?q=` (AC5, my probe) | [v01_blank_query_link.png](verifier/e2e/v01_blank_query_link.png) | "Search" with no back button (cold link, P-087 accepted), the empty field with the caret (focused), "Search for characters and comics by name.", no results | yes |
| Back from the comic to the results (AC5, my probe) | [v02_back_to_results.png](verifier/e2e/v02_back_to_results.png) | After the real Back button: the field still reads `spi`, the Comics chip is still selected, "Comics (400)" and Spindle Chronicles #1…#16 | yes |

I also looked at these without keeping them:
- 30: home with the new "Search" button between Characters and Placeholder 7.
- 31: the search opened from home, with Back, the empty focused field and the hint.
- 33: the Comics chip, showing only "Comics (400)".
- 35: after Back and the clear ×, "Recent searches" with Clear and `spi`.
- 36: `miniclient://app/search?q=spi` as the start link. "Search" with no back button (P-087), the field `spi`, the grouped results.
- 37: the link `?q=amber` sent to the running app. "Characters (38)", Amber Alchemist…, "Comics (200)".
- 01–06 and 10–20: the T-0033 and T-0041 journeys, unchanged apart from the extra home button.

## Issues found
1. **(Low, test gap) The 500 ms open guard is not pinned on either side.**
   - The bloc's `openGuard` is at `feature/discovery/discovery_search/lib/src/presentation/bloc/discovery_search_bloc.dart:30`.
   - **V11** (1 ms) and **V11b** (501 ms) both survive.
   - "A double tap on a result hands it over once" taps twice in the same frame, so any guard longer than 0 passes.
   - "A result can be opened again once the first open has settled" (`test/feature/discovery_search.feature:187-194`) means to tap 500 ms apart. But `tapResult` (`test/feature/util/discovery_search_env.dart:152-158`) runs `scrollUntilVisible` and `mcSettle`, which is 500 ms more of fake time, before its tap. The second tap therefore lands more than 1 s after the first.
   - AC3's "exactly once" holds. The bricks would copy a scenario that does not test what its `{500} milliseconds pass` step says.
   - **Suggestion:** tap again after 499 ms (ignored) and after 500 ms (opened), with a tap step that does not settle first.
2. **(Low, test gap) The failed-Clear version check is untested.**
   - The check is `if (failed && version == _historyVersion)` at `discovery_search_bloc.dart:157`. **V02** (drop the version part) survives.
   - Failure mode without the check: a Clear that fails while a later save is still on its way would put back the pre-save list and hide the new query until the next read.
   - The case is narrow: Clear shows only in idle, and a save needs a search that found something.
3. **(Low, test gap, `mc_paging`) `submit`'s blank branch does not reset the last query, and no test notices.**
   - The line is `_searched = null;` at `utility/mc_paging/lib/src/query/debounced_query.dart:78`. **V14** removes it and survives: the test "a blank submit clears only after a search fired" never searches the same text again after the blank submit.
   - Coverage is 100 %, but the line's effect is not asserted.
   - The bloc never submits a blank text today: the flow maps a blank query to null, and the history holds no blanks.
4. **(Low, test gap, cross-cutting) Nothing asserts that a failed search reaches monitoring.**
   - **V27** removes `@Implements<McFailureState>()` (`feature/discovery/discovery_search/lib/src/presentation/bloc/discovery_search_state.dart:32`) and survives every target.
   - The scenarios assert only the absence of errors (`no error was reported`). That step itself is sound: V27b is killed.
   - One positive assertion in the failure outline, for example "an error was reported", would pin D-16 for every SR brick.
5. **(Low, UX) The keyboard's Search key does nothing.**
   - `McSearchField` sets `textInputAction: TextInputAction.search`, but the page passes no `onSubmitted` (`feature/discovery/discovery_search/lib/src/presentation/page/discovery_search_page.dart:94-103`).
   - My probe P4 sends the search action right after typing "spi" and sees 0 requests. Its title "searches at once" names the behaviour I tested for; the assertion records what happens.
   - The user waits for the 300 ms debounce instead. Wiring `onSubmitted` to the existing `submitted` event (`DebouncedQuery.submit`) would search at once, with no duplicate request.
6. **(Low, docs) Stale comment.**
   - `feature/discovery/discovery_search/lib/src/flow/discovery_search_flow_state.dart:10-12` still says the initial query "is searched once typing would have paused".
   - Since review item 3 it is searched at once (`submit`). A brick would copy the comment.

## Notes for the Tech Lead
- **Not counted against the task, as briefed:**
  - `app_core` coverage (P-088);
  - the field below `McAppBar`;
  - suggestions dropped;
  - no back button on a cold `/search` link (P-087, seen in 36 and v01);
  - a possible T-0048 merge first.
- **"Nothing reaches monitoring" for the folded too-short query.** Nothing is *reported*: no `recordError` and no failure state. My probe P3 shows the transport's `MonitoringInterceptor` still logs one `warning` line, `GET /v1/search failed: 400`. It does that for every failed attempt (and logs every success at `debug`), so I read the TL's item 5 as satisfied. If "nothing" was meant literally, the interceptor would need a per-request opt-out.
- **What is outside the byte-identity check.** It covers the feature's 11 outputs only. The wiring's go_router and injectable outputs are not compared with build_runner. AC7 names only the feature, so this is not a defect.
- **Issues 1 to 6 can go to pending-work, or into the P1-24 bricks pass.** None needs a re-verification.
