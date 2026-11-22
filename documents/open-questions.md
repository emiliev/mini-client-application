# Open Questions (for the Product Owner)

Only **direction-level** questions belong here. Technical questions are decided by the Tech Lead through ADRs ([escalation boundary](fleet/protocol.md#escalation-boundary)). Each question has a default the fleet will use if a decision isn't needed urgently. Answered questions stay here with their answer.

| ID | Question | Status | Blocks | Default if unanswered |
|---|---|---|---|---|
| [Q-001](#q-001) | What is mini-client? | **Answered** 2026-11-22 | — | — |
| [Q-002](#q-002) | Target platforms | **Answered** 2026-11-22 | — | — |
| [Q-003](#q-003) | Backend / API integration | **Answered** 2026-11-22 | — | — |
| [Q-004](#q-004) | App identity (org / bundle id) | **Answered**, spelling to confirm | T-0003 (soft) | use `com.emiliev.miniclinet` exactly as given |
| [Q-005](#q-005) | Repo hosting & integration policy | **Answered** 2026-11-22 | — | — |
| [Q-006](#q-006) | Architecture & tech stack | **Open**: PO is sharing it next | T-0003, T-0004 | — |
| [Q-007](#q-007) | Public store release vs. Marvel IP licensing | **Open** | Phase 3 (release) | build store-ready, but public release gated on licensing; placeholder art |
| [Q-008](#q-008) | Confirm the MVP feature set | **Open** | T-0002 acceptance | proposed set F1 to F5 in the [charter](project/charter.md#mvp-features-proposed) |
| [Q-009](#q-009) | Android toolchain on this Mac | **Answered** 2026-11-22: Android deferred | — | — |

---

### Q-001
**What is mini-client?** Asked 2026-11-22.
**Answer, 2026-11-22:** a Flutter, mobile-first **Marvel application**, to be distributed on iOS and Android.

### Q-002
**Which platforms must it run on?** Asked 2026-11-22.
**Answer, 2026-11-22:** iOS and Android.

### Q-003
**What does it talk to?** Asked 2026-11-22.
**Answer, 2026-11-22:** a **mocked backend**. No real backend exists, and none will be built in this effort. Task work includes building a `mocked_backend` module that provides all of the client's data. See [ADR-0005](adr/0005-mocked-backend-module.md).

### Q-004
**App identity.** Asked 2026-11-22.
**Answer, 2026-11-22:** org / bundle id `com.emiliev.miniclinet`.
**To confirm:** is the spelling `miniclinet` intended, or should it be `miniclient`? A bundle id can't change after the first store release. Until confirmed, the fleet uses the value exactly as given.

### Q-005
**Hosting & integration.** Asked 2026-11-22.
**Answer, 2026-11-22:** GitHub `origin` ([emiliev/mini-client-application](https://github.com/emiliev/mini-client-application), private). **Merge policy confirmed by the PO, 2026-11-22:** "I trust you and your decisions; you can merge PRs." The **TL reviews, merges and pushes to `main`** without asking for approval ([ADR-0004](adr/0004-git-integration-workflow.md)). If `gh` gets authenticated, the same authority covers opening and merging GitHub PRs.

### Q-006
**Architecture & tech stack.** Asked 2026-11-22.
**Status:** the PO will share the architecture and tech stack next. T-0003 (scaffold) and T-0004 (architecture ADRs) wait for it, because it may set the project generator, lints, monorepo layout, state management and more.
**Answer:** _pending_

### Q-007
**Public store release vs. Marvel IP.** Asked 2026-11-22.
Publishing a Marvel-branded app on the App Store or Google Play normally requires a licence from Marvel / Disney. Apple guideline 5.2 and Google's IP policy reject unlicensed use of trademarks and copyrighted art. Is a **public** store release a real goal, or is this a portfolio / demo app distributed privately (TestFlight, Play internal testing)?
**Default:** build it fully store-ready (signing, release builds) but treat a public listing as gated on licensing. Bundle only placeholder or original artwork, and keep Marvel logos out of the app name and icon ([R-005](risks.md)).
**Answer:** _pending_

### Q-008
**Confirm the MVP feature set.** Asked 2026-11-22.
The PO said "a Marvel application" without listing features. The TL proposed F1 to F5 in the [charter](project/charter.md#mvp-features-proposed): browse characters, search characters, character details, browse comics and comic details, and favorites. Add, remove or reorder as you like.
**Default:** build F1 to F5 in that order.
**Answer:** _pending_

### Q-009
**Android toolchain.** Asked 2026-11-22.
This Mac has no Android SDK (`flutter doctor`: "Unable to locate Android SDK"), so the fleet can't build or e2e-test Android locally. iOS is fully covered. Options:
- **(a)** The TL installs the Android command-line tools, platform tools and one emulator image through Homebrew and `sdkmanager`: roughly 5 to 8 GB on your machine, plus a JDK if needed.
- **(b)** You install Android Studio yourself, and the fleet uses its SDK and emulator.
- **(c)** Android is verified only in GitHub Actions (APK build plus unit and widget tests; emulator e2e can be added to CI later, using Actions minutes).

**Default:** (c) until you choose.
**Answer, 2026-11-22:** "Ignore Android for now, let's focus on testing with iOS." None of (a) to (c): Android verification is **deferred** entirely, including in CI. iOS is the only verified platform until the PO re-enables Android ([P-014](pending-work.md)).
