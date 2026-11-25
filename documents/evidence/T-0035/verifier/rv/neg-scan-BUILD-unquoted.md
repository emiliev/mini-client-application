# T-0035-AC4: vendored flow_builder provenance (evergreen)

| Check | Result | Required |
|---|---|---|
| pub.dev archive | sha256 matches | sha256 matches |
| lib/ vs archive | lib/ = archive + 0001-forward-pushRouteInformation.patch (20 changed lines) | archive + the patch |
| LICENSE vs archive | byte-equal | byte-equal |
| BUILD / BUILD.bazel / *.bzl naming `pub_deps//:flow_builder` | ./utility/mc_feature_flow/BUILD  | none |
| pubspec.yaml declaring flow_builder with a source | none | none |
| flow_builder entries in pubspec.lock | 0 | 0 |

**FAIL T-0035-AC4-provenance**
