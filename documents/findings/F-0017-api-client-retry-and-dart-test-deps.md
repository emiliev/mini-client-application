# F-0017: retry interceptor ordering, Dio error shapes, `dart_test` on the mocked backend (T-0023)

- **Date:** 2026-11-23
- **Author:** crew: Engineer (T-0023)
- **Type:** Gotcha
- **Related:** T-0023, F-0015

1. **Interceptor order is `[monitoring, retry]`.** The retry interceptor re-enters `dio.fetch` (marked with an `extra` flag so the inner run does not retry again), which passes through every interceptor. With logging first, each attempt is logged exactly once (3 log lines for GET 503 with 2 retries). Logging after retry would log the final failure twice.
2. **A malformed 200 body surfaces as `DioException(type: unknown, error: FormatException)`**, not as a bare `FormatException`. `ApiFailure.from` checks the wrapped error.
3. **`DioExceptionType.transformTimeout` exists from Dio 5.11** (the lock has 5.11.1); the analyzer's exhaustive-switch check fails without it. Both packages now require `dio: ^5.11.0`. It maps to `ApiTimeout`.
4. **`dart_test` (package `test`) works against `mc_mocked_backend` and `mc_fixtures_characters`**, including the transitive `flutter_library` `mc_fixtures_media`, so F-0015 item 1 no longer applies to new packages (`test` is in the lock now).
5. The mock's `FailureTrigger.times(n)` plus `backend.recentTraffic.length` is the way to assert attempt counts.
6. **Retry and request bodies:** a `FormData` is single-use (finalized by the first attempt), so each retry sends `FormData.clone()`; a `Stream` body cannot be replayed, so it is never retried and the original failure reaches the caller. A receive timeout is not retried (a full receive timeout per attempt). The backoff races the request's `CancelToken`.
7. `mc_mocked_backend` tests now use `package:test` (`dart_test`); the package no longer declares Flutter.
