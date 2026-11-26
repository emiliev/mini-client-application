#!/bin/bash
# T-0038 Verifier follow-up: (a) for the art-set drift mutations M6/M7, is the
# drift test itself ("the ID contract constants match the real packages") red?
# (b) does the Verifier probe file kill M13 (id tie-break removed), which the
# engineer's tests let survive?
set -uo pipefail
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a4f8e6eca40aa2f76
cd "$W" || exit 2
OB=/tmp/mc-ob-T-0038-verifier
TL="$OB/execroot/_main/bazel-out/darwin_arm64-fastbuild/testlogs/utility/mc_fixtures_comics"
EV="$W/documents/evidence/T-0038/verifier"
OUT="$EV/mutations_followup.log"
L=utility/mc_fixtures_comics/lib/src/data/links.dart
H=utility/mc_fixtures_comics/lib/src/handlers/comics_handlers.dart
PROBE=utility/mc_fixtures_comics/test/zz_t0038_verifier_probe_test.dart
trap 'git checkout -- "$L" "$H"; rm -f "$W/$PROBE"' EXIT
: > "$OUT"
for m in "M6|s/const int coverImageCount = 24;/const int coverImageCount = 23;/" \
         "M7|s/const String coverImageSet = 'characters';/const String coverImageSet = 'comics';/"; do
  IFS='|' read -r id expr <<< "$m"
  perl -0pi -e "$expr" "$L"
  git diff --quiet -- "$L" && { echo "$id NOT APPLIED" >> "$OUT"; continue; }
  "$W/tool/bazelw" --output_base="$OB" test --nocache_test_results //utility/mc_fixtures_comics:provider_contract_test > /dev/null 2>&1
  echo "$id drift test: $(grep -a -E '^ *(PASS|FAIL) .*ID contract constants' "$TL/provider_contract_test/test.log" | sed 's/^ *//')" >> "$OUT"
  git checkout -- "$L"
done
cp "$EV/verifier_probe_test.dart" "$W/$PROBE"
perl -0pi -e 's/primary != 0 \? primary : a\.id\.compareTo\(b\.id\)/primary/' "$H"
git diff --quiet -- "$H" && echo "M13 NOT APPLIED" >> "$OUT"
(cd utility/mc_fixtures_comics && fvm flutter test test/zz_t0038_verifier_probe_test.dart -r expanded 2>&1) > /tmp/mc-T-0038-verifier-m13-probe.log
echo "M13 with Verifier probes: $(grep -a -E 'VP5|All tests passed|Some tests failed' /tmp/mc-T-0038-verifier-m13-probe.log | grep -a -E '\[E\]|All tests|Some tests' | tr '\n' ' ')" >> "$OUT"
git checkout -- "$H"
rm -f "$W/$PROBE"
cat "$OUT"
git status --short
