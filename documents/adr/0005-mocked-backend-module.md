# ADR-0005: Mocked backend as an in-repo module

- **Status:** Accepted (scope and principles). Transport and package layout are deferred to T-0004, after the PO's stack (Q-006).
- **Date:** 2026-11-22
- **Deciders:** Product Owner (no real backend; a `mocked_backend` module provides all data), Tech Lead (principles)
- **Related:** Q-003, T-0004, T-0007, T-0008, R-005, R-006

## Context
The PO stated that there is no backend and none will be built in this effort. As part of task implementation we build a `mocked_backend` module that provides all of the client's data. A mock-backed app can easily hide the problems a real network brings (latency, failures, pagination), and can leak mock details into feature code.

## Decision
1. **A separate module.** `mocked_backend` is its own Dart package in this repo. The exact path (e.g. `packages/mocked_backend/`) and workspace tooling are decided with the stack in T-0004. It owns all fixture data and its API surface.
2. **The app never touches fixtures directly.** Features depend on a data-source / repository abstraction. `mocked_backend` is one implementation, and a real backend can replace it with no change to feature code.
3. **It behaves like a real backend:**
   - async API, with **simulated latency** (configurable, zero in tests)
   - **pagination** (offset and limit, with total counts), **search and filter** (e.g. name prefix) and ordering
   - **injectable failures** (timeouts, server errors, empty results), so loading, error and retry UI can be built and tested
   - **deterministic** output, so tests can rely on it
4. **Data contract.** Model the domain on Marvel's public API shapes (characters, comics, series, events, creators) if research (T-0008, F-0003) confirms a documented contract. That keeps the mock realistic and a future swap cheap.
   _Resolved 2026-11-22 ([F-0003](../findings/F-0003-marvel-api-unavailable.md)): the official API is gone (portal redirects, gateway returns 500). The contract is our own domain-first design, owned and documented by T-0007. It borrows familiar ideas (paginated envelope, image path plus variant) without claiming compatibility._
5. **Content.** Fixture text is original or factual summaries. Images are placeholders or original art; no copyrighted Marvel artwork is bundled by default ([R-005](../risks.md), [Q-007](../open-questions.md#q-007)).

## Deferred to T-0004
How the app reaches the mock: an in-process Dart API, an HTTP-client-level mock (an adapter or interceptor), or a local HTTP server. This depends on the networking stack the PO is about to share.

## Consequences
- **Positive:** features are built and tested against realistic behaviour; the data layer is swappable; the mock doubles as test infrastructure.
- **Negative:** we have to write and maintain a realistic fixture dataset.
- **Follow-ups:** T-0007 (build the module), T-0008 (contract research).
