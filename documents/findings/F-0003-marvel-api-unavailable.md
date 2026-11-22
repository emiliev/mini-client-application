# F-0003: The official Marvel API is effectively unavailable

- **Date:** 2026-11-22
- **Author:** crew: Researcher (portal fetch); Tech Lead (gateway probe)
- **Type:** Spike
- **Related:** T-0008, ADR-0005, T-0007

## Summary
The Marvel developer portal no longer serves documentation, and the API gateway returns server errors. We can't verify the official data contract, and there is no live Marvel API to swap the mock for later. **The `mocked_backend` contract is ours to design.**

## Evidence
| Probe (2026-11-22) | Result |
|---|---|
| `https://developer.marvel.com/docs` | `301` → `https://www.marvel.com/` (consumer homepage) |
| `https://developer.marvel.com/documentation/getting_started` | `301` → `https://www.marvel.com/` |
| `https://developer.marvel.com/` | `301` → `https://www.marvel.com/` |
| `GET https://gateway.marvel.com/v1/public/characters` (no key) | `500 {"message": "Internal server error"}`. A working gateway would reject a missing key with a 4xx, not a 500. |

The researcher didn't search for archived copies of the old docs; that was out of scope.

## Implications / actions
- ADR-0005 point 4 resolves to: **design our own domain-first contract.** We can borrow familiar ideas from the historical Marvel API (a paginated envelope with offset, limit, total and count; image as path plus variant), but nothing claims compatibility with it.
- The "swappable data layer" goal (charter goal 4) still holds as good architecture. The realistic swap target is a hypothetical future backend, not Marvel's API.
- T-0007 owns the contract and documents it (models, pagination, errors) as part of the module.
- An archived copy of the old docs could be consulted for field-naming inspiration. Low value; not planned.
