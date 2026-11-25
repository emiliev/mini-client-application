# T-0034-AC4: relative retrofit paths

- retrofit verb annotations scanned: 1

| Check | Result |
|---|---|
| leading-slash paths | /private/tmp/claude-501/old/feature/characters/characters_list/lib/src/domain/api/characters_list_api.dart:21:  @GET('/v1/characters') |
| config apiBaseUrl without a trailing slash | none |
| negative control (planted `@GET('/x')`) | tripped |

**FAIL T-0034-AC4-relative-paths**
