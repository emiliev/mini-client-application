# Open Questions (for the Product Owner)

Only **direction-level** questions belong here. Technical questions are decided by the Tech Lead through ADRs ([escalation boundary](fleet/protocol.md#escalation-boundary)). Each question has a default the fleet will use if a decision isn't needed urgently. Answered questions stay here with their answer.

| ID | Question | Status | Blocks | Default if unanswered |
|---|---|---|---|---|
| [Q-001](#q-001) | What is mini-client? | **Answered** 2026-11-22 | — | — |
| [Q-002](#q-002) | Target platforms | **Answered** 2026-11-22 | — | — |
| [Q-003](#q-003) | Backend / API integration | **Answered** 2026-11-22 | — | — |
| [Q-004](#q-004) | App identity (org / bundle id) | **Answered**, spelling to confirm | T-0003 (soft) | use `com.emiliev.miniclinet` exactly as given |
| [Q-005](#q-005) | Repo hosting & integration policy | **Answered** 2026-11-22 | — | — |
| [Q-006](#q-006) | Architecture & tech stack | **Answered** 2026-11-22: Tide Miniclient ("Lego") architecture, enterprise stack, Bazel | — | — |
| [Q-007](#q-007) | Public store release vs. Marvel IP licensing | **Open** | Phase 3 (release) | build store-ready, but public release gated on licensing; placeholder art |
| [Q-008](#q-008) | Confirm the MVP feature set | **Superseded** 2026-11-23 by the 169-module catalogue (plan 01) | — | — |
| [Q-009](#q-009) | Android toolchain on this Mac | **Answered** 2026-11-22: Android deferred | — | — |
| [Q-010](#q-010) | LOC definition: does committed scaffolded source count? | **Open** | S2/S3 gates (plan R1) | Yes: committed first-party `.dart`, build-time generated code excluded, hand share reported |
| [Q-011](#q-011) | Goal split for release AOT at 5 to 10M LOC | **Open** | Phase G sign-off (plan R27) | Dev loop must pass budget16 at every rung; release AOT must pass up to S3 and is reported at S4 |
| [Q-012](#q-012) | budget16 fidelity: VM tool (L2) and a real 16 GB Mac (L3) | **Open** | Phase G sign-off | L1 (wired-memory ballast on this Mac) only; final numbers flagged as simulated |
| [Q-013](#q-013) | GitHub access for upstream issues and PRs | **Open** | Filing upstream (D12, R11) | Issues and PRs drafted in `documents/upstream/`, patches kept in the in-repo queue |
| [Q-014](#q-014) | Apple Developer team for device builds | **Open** | Device AOT builds on hardware | Device builds deferred; AOT measured via build-only targets |

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
**Answer, 2026-11-22 (PO, summarised faithfully):**
- **Architecture:** Tide's "Lego" architecture from the *Project Miniclient* Medium series: introduction, utility layer, feature level, application layer, navigation, testing ([intro](https://medium.com/tide-engineering-team/project-miniclient-introduction-0a94aefa5638)). Go through all the articles and understand them in detail.
- **Stack:** "freezed, feature flow, injectable, l10n, retrofit, etc.", i.e. the stack the articles use.
- **Scale:** an enterprise Marvel app with **at least 100 modules, including BDD tests**.
- **Build:** integrate with **Bazel** using [Mivr/ai_rules_dart](https://github.com/Mivr/ai_rules_dart) and [Mivr/ai_rules_flutter](https://github.com/Mivr/ai_rules_flutter).
- **End goal:** stress-test the Bazel rules, profile them extensively, and identify, apply and **report upstream** every issue, so these become the most optimised Flutter and Dart rules. They must build the app; cache hits must be accurate; incremental changes must rebuild and assemble only what changed; RAM use must be optimal (Flutter AOT and JIT are memory-hungry), so that a **5 to 10M LOC** Flutter project runs comfortably on a **16 GB** laptop.
- **This turn's deliverable:** a plan for building a **500k to 1M LOC (minimum)** app. Split the work across agents, including for planning, then assemble it. A separate set of agents then verifies that the plan follows the Tide articles.
- Tracked in T-0013.

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

### Q-010
**LOC definition.** Asked 2026-11-23. Hand-typing 500k to 1M lines would take hundreds of agent tasks. The plan builds verified exemplars by hand, then a generator (`tool/mcgen`) produces the rest as committed, reviewed source that the compiler, the analyzer and Bazel treat exactly like typed code. Build-time generated code (freezed, json, injectable, retrofit, l10n, BDD) is **not** counted. Reports always show the hand-written and scaffolded split. Is that acceptable for the 500k to 1M target?
**Default:** yes, as above (plan R1, ADR-0009).
**Answer:** _pending_

### Q-011
**Release AOT at 5 to 10M LOC.** Asked 2026-11-23. A release AOT build runs one whole-program compiler process (TFA, then `gen_snapshot`) whose memory grows with program size; no Bazel scheduling can make one process smaller. It may not fit 16 GB at 5 to 10M.
**Proposed split:** the dev loop (simulator debug, tests, analysis, incremental) must pass budget16 at every rung. Release AOT must pass up to S3 (about 1M), and is measured and reported at S4. If one process exceeds 8 GiB, we escalate to the Dart SDK.
**Default:** this split.
**Answer:** _pending_

### Q-012
**budget16 fidelity.** Asked 2026-11-23. Simulation levels:
- L1: wired-memory ballast on this 48 GB Mac
- L2: a 16 GiB / 8 vCPU macOS VM (needs a VM tool installed)
- L3: a real 16 GB Mac, or a cloud Mac

May we install a VM tool, and is a 16 GB machine available for final sign-off?
**Default:** L1 only; final numbers labelled "simulated".
**Answer:** _pending_

### Q-013
**GitHub access for upstream work.** Asked 2026-11-23. Filing issues and PRs on `Mivr/ai_rules_dart` / `ai_rules_flutter` (and on injectable / lean_builder) needs `gh auth login` on this Mac, plus your OK to fork those repos under your account and to file in your name. Until then, everything is drafted in `documents/upstream/` and patches stay in our in-repo queue.
**Default:** draft only.
**Answer:** _pending_

### Q-014
**Apple Developer team.** Asked 2026-11-23. Running AOT builds on a physical iPhone needs a team and a provisioning profile.
**Default:** device builds deferred; AOT is built and measured without installing.
**Answer:** _pending_
