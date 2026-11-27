# T-0050-AC1 before the fix

Commit with the authPinned helper and the AC1 test but no guard in AuthInterceptor.onRequest (the interceptor is origin/main's). 4 of 10 tests fail: the pinned write goes out under the new user's bearer. Log: AC1_before_fix.log
