# T-0034-AC4: relative retrofit paths

- retrofit verb annotations scanned: 9

| Check | Result |
|---|---|
| leading-slash paths | app/verifier_plant.dart:2: @GET( '/v1/a/very/long/path/that/dart/format/would/wrap/onto/its/own/line
app/verifier_plant.dart:6: @POST("/v1/b
app/verifier_plant.dart:8: @GET(r'/v1/c
app/verifier_plant.dart:10: @PUT( r"/v1/d |
| config apiBaseUrl without a trailing slash | none |
| negative controls (one-line, multi-line, raw, double-quoted; a relative path stays quiet) | all behave |

**FAIL T-0034-AC4-relative-paths**
