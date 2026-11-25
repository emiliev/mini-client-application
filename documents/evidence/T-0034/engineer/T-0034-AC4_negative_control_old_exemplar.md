# T-0034-AC4: relative retrofit paths

- retrofit verb annotations scanned: 1

| Check | Result |
|---|---|
| leading-slash paths | /private/tmp/claude-501/old/feature/characters/characters_list/lib/src/domain/api/characters_list_api.dart:21: @GET('/v1/characters |
| config apiBaseUrl without a trailing slash | none |
| negative controls (one-line, multi-line, raw, double-quoted; a relative path stays quiet) | all behave |

**FAIL T-0034-AC4-relative-paths**
