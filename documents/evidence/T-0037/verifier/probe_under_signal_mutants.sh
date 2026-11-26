#!/bin/bash
# Runs the verifier probes with V9 (route.canPop) and V10 (Navigator.canPop())
# in place of `!route.isFirst`, then restores feature_flow.dart.
set -uo pipefail
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a23fd7f7ae6d56c1d
S=/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/T-0037-verifier
cd "$W" || exit 2
F=utility/mc_feature_flow/lib/src/feature_flow.dart
cp -f "$F" "$S/ff.bak"
trap 'cp -f "$S/ff.bak" "$F"' EXIT
for m in 'route?.canPop ?? false' 'route != null \&\& Navigator.of(context).canPop()'; do
  cp -f "$S/ff.bak" "$F"
  sed -i '' "s/outerCanPop: route != null \&\& !route.isFirst,/outerCanPop: $m,/" "$F"
  echo "=== $(grep -n 'outerCanPop:' "$F")"
  (cd utility/mc_feature_flow && fvm flutter test test/zz_verifier_t0037_probe_test.dart -r expanded 2>&1 \
    | grep -a -E '\[E\]|All tests|Some tests|VP10 ')
done
