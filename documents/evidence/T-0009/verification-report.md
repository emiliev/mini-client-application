# Verification report — T-0009: Verification pipeline spike (iOS)

- **Verifier:** Tech Lead (spot-check). A spike has no product code, so a full fresh-Verifier pass wasn't warranted; the TL independently checked the claims below.
- **Date:** 2026-11-22
- **Artifact verified:** throwaway app `verify_spike` in the TL scratchpad (outside the repo)
- **Simulators:** `mc-spike`, `mc-spike-2` (iPhone 17 Pro, iOS 26.2), created and deleted by the Engineer
- **Verdict:** PASS

## Claims re-checked independently
| Claim | How the TL checked it | Result |
|---|---|---|
| Coverage 93.55 % | Re-ran the awk over `coverage/lcov.info` | 93.55 %, matches |
| Simulators cleaned up | `xcrun simctl list devices \| grep -c mc-` | 0, matches |
| Repo untouched | `git status --short` in the TL worktree | clean, matches |
| E2E really asserts navigation | Read `integration_test/app_test.dart` | Asserts `DetailScreen` present, the "Detail: Item 15" title and the `detail_title` text, so it's genuine |
| Screenshot driver writes PNGs | Read `test_driver/integration_test.dart` | `integrationDriver(onScreenshot:)` writes to `$SCREENSHOT_DIR`, matches |
| Screenshots show the described UI | Viewed the images | see below, matches |

## Acceptance criteria
| AC | Scenario (short) | Evidence | Result |
|---|---|---|---|
| T-0009-AC1 | Widget tests pass, with commands and timings | Engineer report (3 passed, 6.5 s) | PASS |
| T-0009-AC2 | Golden fails on UI change, diff location known | `test/failures/*`; isolated diff below | PASS |
| T-0009-AC3 | Coverage % computable without tools | awk re-computed by the TL | PASS |
| T-0009-AC4 | E2E passes on a dedicated simulator, timings recorded | 41 s cold / 13 s warm | PASS |
| T-0009-AC5 | In-test and out-of-test screenshots, viewable by an agent | 2 + 2 PNGs, viewed by the TL | PASS |
| T-0009-AC6 | Two simulators booted in parallel, then deleted | Engineer report; 0 left over (TL check) | PASS |

## Visual acceptance
| Checkpoint | Screenshot | What is visible (TL's own reading) |
|---|---|---|
| Out-of-test launch (`simctl`) | [simctl-launch-list.png](simctl-launch-list.png) | Real iOS status bar (16:34, Dynamic Island, wifi, battery), lavender app bar "Spike", rows Item 0 to Item 12 with chevrons, Item 13 cut off |
| In-test detail checkpoint | [in-test-detail-item15.png](in-test-detail-item15.png) | Back chevron, app bar "Detail: Item 15", centred "Item 15"; blank strip where the status bar would be (expected for in-test capture) |
| Golden master | [golden-list-ahem-font.png](golden-list-ahem-font.png) | 400×800 list rendered in the Ahem font, so all text is black boxes and icons are squares (F-0004 gotcha 1) |
| Golden failure diff | [golden-failure-isolated-diff.png](golden-failure-isolated-diff.png) | Fully dark isolated diff: every pixel changed after the colour swap |

## Issues found
1. (minor) Goldens aren't readable by people because of the Ahem font. Follow-up: load real fonts (T-0005).
2. (minor) `simctl clone` fails on a booted device. Follow-up: always `create` (ADR-0006 §6 updated).

## Notes for the Tech Lead
The pipeline is feasible and fast enough for a per-task Verifier pass: about 1 minute for a warm e2e plus screenshots.
