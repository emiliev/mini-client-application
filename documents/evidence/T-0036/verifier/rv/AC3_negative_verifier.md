# T-0036-AC3: gates, greps and mutations

| Gate | Result |
|---|---|
| no flowLeading in code | **FAIL** |
| stale comments fixed | **FAIL** |

### no flowLeading in code failed

```
flowLeading still used:
/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/T-0036-verifier/neg/feature/x/planted.dart:1:  Widget? x() => context.flowLeading();
```

### stale comments fixed failed

```
stale comments:
feature_flow.dart: stale 'Empty:' line
api_client_test.dart: 'assertion above'
BUILD.bazel: 'skipped until T-0035'
```

**FAIL T-0036-AC3-gates**
