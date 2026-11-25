# T-0035 negatives: each planted defect must make the check FAIL

- FAIL as required (T-0035-AC4_provenance.sh): quoted @pub_deps//:flow_builder in a BUILD.bazel
- FAIL as required (T-0035-AC4_provenance.sh): unquoted pub_deps//:flow_builder in a .bzl
- FAIL as required (T-0035-AC4_provenance.sh): plain-named BUILD file with the ref
- FAIL as required (T-0035-AC4_provenance.sh): hosted flow_builder in a pubspec
- FAIL as required (T-0035-AC4_provenance.sh): flow_builder git source on one line
- FAIL as required (T-0035-AC4_provenance.sh): a hosted flow_builder entry in pubspec.lock
- FAIL as required (T-0035-AC4_provenance.sh): an extra line in the vendored lib
- FAIL as required (T-0035-AC4_provenance.sh): LICENSE edited
- FAIL as required (T-0035-AC4_lock_delta.sh): an unrelated extra package in pubspec.lock
- FAIL as required (T-0035-AC4_lock_delta.sh): an unrelated change in MODULE.bazel.lock
- PASS as required (T-0035-AC4_provenance.sh): simulated post-merge main (lock moved by another change)
- FAIL as expected (T-0035-AC4_lock_delta.sh): one-off check is for the branch only, not for a moved main

overall: OK
