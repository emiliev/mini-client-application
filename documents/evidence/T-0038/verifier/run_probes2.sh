#!/bin/bash
# T-0038 Verifier re-verification: run both probe files (VP1-VP11 and RV1-RV4)
# on the unmodified HEAD, then remove them from the package.
set -uo pipefail
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76
cd "$W" || exit 2
EV="$W/documents/evidence/T-0038/verifier"
T=utility/mc_fixtures_comics/test
trap 'rm -f "$W/$T/zz_t0038_verifier_probe_test.dart" "$W/$T/zz_t0038_verifier_probe2_test.dart"' EXIT
cp "$EV/verifier_probe_test.dart" "$W/$T/zz_t0038_verifier_probe_test.dart"
cp "$EV/verifier_probe2_test.dart" "$W/$T/zz_t0038_verifier_probe2_test.dart"
(cd utility/mc_fixtures_comics && fvm flutter test test/zz_t0038_verifier_probe_test.dart test/zz_t0038_verifier_probe2_test.dart -r expanded 2>&1) \
  | grep -a -v -E '^  [a-z_]+ [0-9.]+ \([0-9.]+ available\)' > "$EV/probes_38354b9.log"
rc=${PIPESTATUS[0]}
echo "HEAD: $(git rev-parse --short HEAD), rc=$rc" >> "$EV/probes_38354b9.log"
grep -a -E '^\d\d:\d\d \+[0-9]+( -[0-9]+)?: ' "$EV/probes_38354b9.log" | sed 's/.*: //' | tail -20
grep -a -E 'Expected|Actual|Which|reason|\[E\]' "$EV/probes_38354b9.log" | head -30
tail -2 "$EV/probes_38354b9.log"
