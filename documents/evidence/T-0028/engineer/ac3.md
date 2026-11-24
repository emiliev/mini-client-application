# T-0028-AC3: ext lock and vendored generator

Fetched rules_dart (pin + queue): `ai_rules_dart+`

| Check | Value | Required |
|---|---|---|
| analyzer in dart/ext/pubspec.lock | 14.5.0 | 14.5.0 |
| injectable in dart/ext/pubspec.lock | 3.0.0 | 3.0.0 |
| lean_builder in dart/ext/pubspec.lock | absent | absent |
| `bazel build --nobuild` fetch of the patched rules | exit 0 | 0 |
| `query @@ai_rules_dart++pub+ext_pub_deps//:all` | exit 0, analyzer+injectable listed: yes | 0, yes |
| @@ai_rules_dart++pub+ext_pub_deps//:lean_builder target | absent | absent |
| vendored lib/lean_builder/ | absent | absent |
| vendored files importing package:lean_builder | 0 | 0 |
| vendored lib/ vs pub.dev archive | equal to pub.dev 3.1.3 minus lib/lean_builder/ | equal |

**PASS T-0028-AC3**
