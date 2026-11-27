# F-0067: `characters_details`: what was copied from `comics_details`, and what differed

- **Date:** 2026-11-27
- **Author:** crew: Engineer (T-0067)
- **Type:** Design record / Lesson
- **Related:** T-0067, T-0041, T-0050, T-0056, T-0059, ADR-0012, ADR-0015, F-0040, F-0050, F-0056, F-0059

## Summary
The character profile is a hand-built SC feature in the shape of `comics_details`. The favourite, its session guards and the open guard were copied nearly verbatim; the data, the page and the analytics are new. **No codegen shim failed on a real-world case** (freezed, json, retrofit, injectable and gen-l10n all built unchanged). The facts below are what the SC brick needs to know about the variation points.

## Copied as is (rename only)
- **Package shape:** `_stage` / `_stage_dto` lanes, `flow_scope.dart` root imports, `di_initializer`, the flow state and the barrel rules (R4).
- **The favourite bloc and its tests:** the shown-epoch guard, `authPinned(epoch)` on both writes, the read after sign-in, the session listener and `DataChanged('favourites')`. The 25 favourite scenarios (the 24 of `comics_details` and one for the seeded favourites) and `bloc_guards_test` are the `comics_details` ones with `character` for `comic`. Nothing in them needed a change but the id.
- **The details bloc's open guard** (500 ms, keyed by the target), now keyed by `ComicId`.
- **Steps:** every sign-in, session and announcement step; the two-pages host.

## What differed
1. **Names.** Public classes are singular (`CharacterDetailsFlow`, `CharacterDetailsNavigator`, `CharacterDetailsL10n`), as the task asked; the package, file and l10n file names stay plural (`characters_details`). `comics_details` is plural throughout. The brick should decide one rule.
2. **Two requests, one page.** The character is `GET /v1/characters/:id`; its comics are the comics domain's reverse lookup `GET /v1/comics?characterId=&limit=20` (the comics fixture lists at most 14 for a character at seed 42). The characters fixture cannot embed comics: `mc_fixtures_comics` depends on it (T-0041).
   - The bloc starts both at once (`(a, b).wait`) and combines them: an unknown character is `notFound` even when the comics failed; any other failure of either fails the page, and Retry reloads both.
   - The retry interceptor retries a failing `GET` twice, so a held-down comics failure is 3 requests; the scenario counts 4 after Retry.
3. **Fixture extension (`mc_fixtures_characters`).** The detail gains `aliases` (0 to 2, `The <word>`) and `stats` (six integers, 1 to 100). Both are drawn **after** every field that was already served, so no existing value moved (the list snapshots are byte-identical; `detail.json` only gained the two fields; a test pins the seed-42 values of the old fields). The synthetic sets compute them from the index. `appearances` stays in the DTO (the contract test round-trips it) but the page does not show it: its counts are random and would contradict the comics row.
4. **Seeded favourites.** `identity.default` seeds `character/100000` and `character/100001` as favourites of the reader, so those two ids start as "Remove from favourites". The feature tests use `100002`; one scenario pins the seeded case.
5. **A chart in a feature (F-0059).** The stats are an `McBarChart` (horizontal). Facts from using it:
   - the labels are l10n strings and the summary names the character; the chart has no l10n;
   - the bars are drawn lazily like any list, but its semantics are built with the chart, so the step scrolls the chart into view and reads `simulatedAccessibilityTraversal()` (the summary, then "Strength: 93", ...); the `SemanticsHandle` must be disposed inside the step, not in `addTearDown`, or the tester fails the test;
   - the DTO keeps the stats as `Map<String, int>`; the mapper emits them in `StatKind` order and throws `FormatException` for a missing or out-of-range key (`ApiMalformed` on the wire).
6. **A horizontal row is lazy too.** The comics row built 3 of 4 cards, so a step that lists "the row" must drag the row and collect the cards (`the comics row lists the comics of character {id}`). `Scrollable.ensureVisible` through `scrollUntilVisible` also moves a horizontal ancestor; scroll to the row key first, then act on its cards.
7. **Analytics (ADR-0012).** The favourite bloc takes `AnalyticsTracker`; the vocabulary is one file (`character_analytics.dart`).
   - `character_favourited` (`id`) is tracked only for a saved favourite: not a removal, a failed write, a backed-out sign-in or a sign-in as a user who already has it.
   - The flow's one page is named `character_details`, the same as the route, so the router observer and `AnalyticsFlowObserver` track it once (`analytics_screens_test`: a cold link gives `character_details`, then Back gives `characters_list`, `home`).
8. **No `isClosed` hole.** F-0056's rule (never `add` after an await without `isClosed`) was checked: neither bloc calls `add` after an await. The favourite bloc's only post-await work is `emit`, the bus publish and the tracker call.
9. **No cover page, so a one-page flow.** `comics_details` has a second flow page (the cover). The profile has none, and the flow state holds only the id. `McFlowBackButton` still leaves the flow from its root page.
10. **Tests (ADR-0015).** No goldens, no mutation script: BDD (57 scenarios), contract tests (`CharacterDto` round trip, the stats mapping as pure logic, the comics page, the favourite answers), `bloc_guards_test` (the stale-tap guard, the analytics count, the open guard keyed by comic) and `flow_scope_test` (root imports, the screen tracked once). The wiring test pushes the comic location and shows the real sheet.
11. **Gherkin and apostrophes.** A value with an apostrophe (`a clockmaker's daughter`) is written `\'` in a step argument (the generator copies it into a single-quoted Dart string, like F-0040 fact 7's `\$`).

12. **E2E traps.**
    - After Back from a comic, the profile is still scrolled to its comics row, so the header (`characters_details.name`) is not built: wait for the row, not the name.
    - "See full profile" is pushed over the preview, so Back from the profile shows the **preview** (a page of the characters_list flow), not the grid; Back from there reaches the list.
    - The cold link `miniclient://app/characters/<id>` still builds `[home, list, profile]` (T-0049): the test taps Back twice.

13. **Review round: three bugs in the copied favourite bloc, fixed in both features.** A `DataChanged` during a tap was dropped; overlapping reads in one epoch could finish in any order; every background re-read emitted `loading` (a flicker and a disabled toggle). Fix: a stale flag, a read counter (a tap bumps it too, so an older read cannot undo a write), and `loading` only for a first read or a new session. A tap during a background read is therefore allowed (the toggle is no longer `loading`). The bricks copy the fixed version.

## Implications / actions
- The SC brick copies sections "Copied" and keeps 2, 5 and 6 as the variation points for a feature with a second request and a chart.
- `identity.default`'s seeded favourites make two characters special in every feature that favourites a character; a brick uses an id outside that list.
- Follow-up: one rule for singular or plural class names (1), and whether the characters list's preview should show the aliases the detail now has.
