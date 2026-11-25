# T-0035-AC4: lock delta against base 6e7eaaf (one-off)

| Check | Result | Required |
|---|---|---|
| pubspec.lock = base minus the flow_builder block | DIFFERS: 223c223
<     version: "17.5.0"
---
>     version: "17.5.1" | identical |
| MODULE.bazel.lock = base minus the flow_builder repo and mentions | equal | equal |

**FAIL T-0035-AC4-lock-delta**
