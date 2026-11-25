# T-0034-AC4: relative retrofit paths

- retrofit verb annotations scanned: 5

| Check | Result |
|---|---|
| leading-slash paths | app/verifier_plant.dart:6:  @POST("/v1/b") |
| config apiBaseUrl without a trailing slash | none |
| negative control (planted `@GET('/x')`) | tripped |

**FAIL T-0034-AC4-relative-paths**
