# T-0035-AC4: lock delta against base 6e7eaaf (one-off)

| Check | Result | Required |
|---|---|---|
| pubspec.lock = base minus the flow_builder block | identical | identical |
| MODULE.bazel.lock = base minus the flow_builder repo and mentions | equal | equal |

**PASS T-0035-AC4-lock-delta**
