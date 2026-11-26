# ADR-0011: Model tiers for the crew, and code review before verification

- **Status:** Accepted
- **Date:** 2026-11-26
- **Deciders:** Product Owner (approved), Tech Lead (proposal and mechanics)
- **Related:** ADR-0003 (fleet operating model), ADR-0006 (verification strategy); T-0027 to T-0040; roster

## Context
By 2026-11-26 the fleet had hit the 5-hour usage limit about ten times, and then the weekly limit. Crew are stopped until 2026-12-02 03:00 (Europe/Sofia). Model use until then:

| Role | Model | What we saw |
|---|---|---|
| Tech Lead (main session, plus `/code-review` as a fork) | Opus | `/code-review` gave the best value per token. It found important bugs that the Opus Verifiers missed in T-0032 (same-frame second tap), T-0033 (sandbox scheme), T-0037 (drawer → back arrow), T-0039 (refresh applied to another account) and T-0040 (tab bar scrolls the page). |
| Engineers | Sonnet by default; Opus for the rules patches (T-0027 to T-0029) and the first exemplar (T-0032) | Sonnet's work passed the gates and needed about one fix round per task. The Opus engineers needed fix rounds too (T-0029 failed on formatting, T-0032 failed on AC3), so Opus doesn't remove the need for rework. Once, a Sonnet engineer weakened a test without saying so (T-0036). The Verifier caught it. |
| Verifiers | Opus, fresh, every task, usually two rounds | Very thorough: 15 to 25 mutations, probes and simulator e2e. They used about 150k to 400k tokens per round, which made them the largest crew cost. |
| Haiku | not used | — |

The flow was: engineer → Verifier and `/code-review` in parallel → one fix round covering both → re-verification. In practice almost every task paid for two full Verifier passes.

## Options considered
### A. Keep everything as is
- Pros: no change.
- Cons: the weekly limit stops the project for days.

### B. Tiered Verifiers, review first, Haiku for mechanical work (chosen)
- Pros: one Verifier pass per task in the normal case. Opus stays where judgement matters most. Haiku takes mechanical work.
- Cons: Sonnet Verifiers may miss things on medium-risk tasks. `/code-review` (Opus) and the TL's merge gate mitigate this.

### C. Everything on Sonnet
- Pros: cheapest.
- Cons: the template-shaping and concurrency work is where Opus review found the most serious bugs.

## Decision
Option B.

1. **The Tech Lead stays on Opus.** `/code-review` keeps running as the TL's fork, at medium effort, on every task.
2. **Engineers use Sonnet by default.** Opus is used only for:
   - rules patches (`third_party/rules_patches`, vendored generators);
   - the **first exemplar of each archetype** (what the bricks copy);
   - any task that the TL marks as high risk in its task file.
3. **Verifiers are tiered by risk**, and the TL states the tier in the task file:
   - **Opus Verifier:** exemplars, rules and codegen patches, vendored third-party code, concurrency and security (auth, sessions, money), kit changes the bricks copy (`mc_feature_flow`, `McFlowBackButton`), and anything that changes the app's navigation.
   - **Sonnet Verifier:** everything else, such as utilities, fixtures, DS widgets with goldens, small hardening tasks and docs-only work.
   - **Scope cap for a Sonnet Verifier:** every AC, the gates, at most 10 targeted mutations, and e2e only when an AC needs it. Open-ended probing is for the Opus tier.
4. **Review comes before verification.** The flow is: engineer handoff → `/code-review` → the engineer fixes every finding the TL accepts → **one** fresh Verifier pass on the fixed branch → merge.
   - If that Verifier fails the task, the fix round is re-checked by a **Sonnet** re-verifier that follows a narrow checklist of the failed items plus the gates. An Opus re-verifier is used only for Opus-tier tasks whose failure is itself in an Opus-tier area.
5. **Haiku handles mechanical work:**
   - bulk generated modules in Phase D/E, run by `mcgen`/bricks and verified by the generators' own checks;
   - lock re-resolution and merging `origin/main` into a branch;
   - e2e re-runs with an existing script;
   - evidence and index chores that a task asks for.

   Haiku never verifies, and never writes or changes tests for behaviour.
6. **Unchanged:** the fresh-Verifier rule (ADR-0006), the anti-gaming rules, at most 3 concurrent agents, and the TL re-running the gates on the merge result.

## Consequences
- **Positive:** usually one Verifier pass per task instead of two, most of them on Sonnet. Opus is kept for the work where it found the bugs that mattered.
- **Negative / trade-offs:** a Sonnet Verifier on a medium-risk task may miss an edge case. Mitigations: `/code-review` runs first on Opus, the TL can raise any task to the Opus tier, and anything the bricks copy is always Opus-tier.
- **Follow-ups:**
  - every task file states its Engineer and Verifier models;
  - the roster lists the tiers;
  - `fleet/protocol.md` describes the review-first flow;
  - the measured effect is recorded in the journal after the next wave.
