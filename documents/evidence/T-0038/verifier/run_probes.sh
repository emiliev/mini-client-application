#!/bin/bash
# T-0038 Verifier: run the probe file on the unmodified HEAD, then remove it.
set -uo pipefail
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76
cd "$W" || exit 2
EV="$W/documents/evidence/T-0038/verifier"
PROBE=utility/mc_fixtures_comics/test/zz_t0038_verifier_probe_test.dart
trap 'rm -f "$W/$PROBE"' EXIT
cp "$EV/verifier_probe_test.dart" "$W/$PROBE"
(cd utility/mc_fixtures_comics && fvm flutter test test/zz_t0038_verifier_probe_test.dart -r expanded 2>&1) \
  | grep -a -v -E '^  [a-z_]+ [0-9.]+ \([0-9.]+ available\)' > "$EV/probes.log"
rc=${PIPESTATUS[0]}
echo "HEAD: $(git rev-parse --short HEAD), rc=$rc" >> "$EV/probes.log"
tail -6 "$EV/probes.log"
rm -f "$W/$PROBE"
git status --short
