# T-0008: Marvel API status & contract research

| Field | Value |
|---|---|
| Status | Done |
| Owner | crew: Researcher (web-fetch), Tech Lead |
| Branch | — (research only) |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | — |
| Related | ADR-0005, F-0003, T-0007 |

## Goal
Find out whether the official Marvel API is live and documented, so `mocked_backend` can mirror its contract and a real-API swap stays possible.

## Acceptance criteria
- [x] The API's status established with evidence.
- [x] The contract approach for `mocked_backend` decided from the result.

## Log
- 2026-11-22: Researcher dispatched in the background on the developer.marvel.com docs pages. All three return a 301 to the marvel.com homepage.
- 2026-11-22: TL probed `gateway.marvel.com/v1/public/characters` → `500 Internal server error`.

## Outcome
- **Result:** the official API is effectively unavailable ([F-0003](../findings/F-0003-marvel-api-unavailable.md)).
- **Decision:** the `mocked_backend` contract is our own domain-first design (ADR-0005 point 4 resolved), owned by T-0007.
- **Follow-ups:** none.
