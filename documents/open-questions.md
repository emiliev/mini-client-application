# Open Questions (for the Product Owner)

Only **direction-level** questions belong here. Technical questions are decided by the Tech Lead through ADRs ([escalation boundary](fleet/protocol.md#escalation-boundary)). Each question has a default the fleet will use if a decision isn't needed urgently. Answered questions stay here with their answer.

| ID | Question | Status | Blocks | Default if unanswered |
|---|---|---|---|---|
| [Q-001](#q-001) | What is mini-client? | **Open** | T-0002, T-0003, T-0004 | none |
| [Q-002](#q-002) | Target platforms | **Open** | T-0003 | iOS + Android |
| [Q-003](#q-003) | Backend / API integration | **Open** | T-0002, T-0004 | none |
| [Q-004](#q-004) | App identity (name, org / bundle id) | **Open** | nothing yet; must be set before first release | `com.example`-style placeholder |
| [Q-005](#q-005) | Repo hosting & integration policy | **Partly answered** (hosting = GitHub) | P-008 (merge policy) | TL merges reviewed branches into `main` and pushes |
| [Q-006](#q-006) | Stack preferences or constraints | **Open** | nothing | TL decides via ADR in T-0004 |

---

### Q-001
**What is mini-client?** Asked 2026-11-22.
- Is it an **app** or a **package / SDK** that other apps use?
- What problem does it solve, and for whom?
- What are the three to five must-have features for the first usable version?
- Is it related to any of your other projects (for example `stac`, `websocket_sample`, `flutter-crypto-app`, `bulltime`)?
- _Hint, 2026-11-22: the GitHub repo is named `mini-client-application`, which suggests an app rather than a package. Not yet confirmed._

**Answer:** _pending_

### Q-002
**Which platforms must it run on?** iOS, Android, web, macOS, Windows, Linux. Asked 2026-11-22.
**Answer:** _pending_

### Q-003
**What does it talk to?** An existing backend or API (REST, GraphQL, WebSocket, Firebase…), or one we build too? Any auth requirements? Asked 2026-11-22.
**Answer:** _pending_

### Q-004
**App identity.** Display name and reverse-domain org id (e.g. `com.<you>.miniclient`). It can be a placeholder until the first store or release build. Asked 2026-11-22.
**Answer:** _pending_

### Q-005
**Hosting & integration.** Will there be a remote (GitHub, GitLab…) for CI and PRs? Should the Tech Lead merge reviewed branches into `main` itself, or do you want to approve merges? Asked 2026-11-22.
**Answer (hosting), 2026-11-22:** GitHub, private repo [emiliev/mini-client-application](https://github.com/emiliev/mini-client-application), linked as `origin` (T-0006, F-0002).
**Still open (merge policy):** should the TL merge reviewed task branches into `main` and push, or do you want to approve each merge through a GitHub PR? For the TL to open PRs itself, run `gh auth login` once on this machine.

### Q-006
**Stack preferences.** Any libraries or patterns you want or don't want (state management, routing, backend SDKs)? Without a preference, the Tech Lead decides and records why. Asked 2026-11-22.
**Answer:** _pending_
