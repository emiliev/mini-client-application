#!/bin/bash
# Verifier mutations for T-0052 (run from the worktree root). Each mutant is
# applied in place, built, tested, and restored with git checkout.
set -u
OB=/tmp/mc-ob-T-0052-verifier
FF=utility/mc_feature_flags/lib/src
T="//utility/mc_feature_flags:evaluation_test //utility/mc_feature_flags:experiments_test //utility/mc_feature_flags:session_fetch_test //utility/mc_feature_flags:registry_overrides_test //utility/mc_feature_flags:di_test"
run() { # id file old new
  local id="$1" f="$2" old="$3" new="$4"
  if ! python3 -c '
import sys
f,o,n=sys.argv[1:4]
s=open(f).read()
if s.count(o)!=1: sys.exit(1)
open(f,"w").write(s.replace(o,n))
' "$f" "$old" "$new"; then echo "$id: PATTERN NOT FOUND"; return; fi
  fvm dart format "$f" >/dev/null 2>&1
  out=$(tool/bazelw --output_base=$OB test $T 2>&1)
  if echo "$out" | grep -q "Build did NOT complete"; then echo "$id: BROKEN"
  elif echo "$out" | grep -q "FAILED in"; then echo "$id: KILLED ($(echo "$out" | grep -c 'FAILED in') targets)"
  else echo "$id: SURVIVED"; fi
  git checkout -q -- "$f"
}
run M1-lkg-before-remote $FF/feature_flags.dart "final snapshot = _remote ?? _lastKnownGood;
    if (snapshot != null) {
      final raw" "final snapshot = _lastKnownGood ?? _remote;
    if (snapshot != null) {
      final raw"
run M2-no-epoch-drop $FF/feature_flags.dart "if (_disposed || epoch != _session.epoch) {
        return;" "if (_disposed) {
        return;"
run M3-weight-cap-1e15 $FF/bucketing.dart "maxVariantWeight = 1000000000;" "maxVariantWeight = 1000000000000000;"
run M4-override-in-release $FF/feature_flags.dart "bool get _overridesAllowed => !isReleaseLikeEnv(_env);" "bool get _overridesAllowed => true;"
run M5-override-skipped $FF/feature_flags.dart "if (_overridesAllowed) {
      final stored = _overrideFlags[flag.key];" "if (false) {
      final stored = _overrideFlags[flag.key];"
run M6-bucket-le $FF/bucketing.dart "if (bucket < cumulative" "if (bucket <= cumulative"
run M7-fnv-prime $FF/bucketing.dart "hash * 403" "hash * 402"
run M8-no-cache-delete $FF/feature_flags.dart "if (userId != _seenUserId) {
      // The saved" "if (false) {
      // The saved"
run M9-lkg-other-user $FF/feature_flags.dart "_lastKnownGood = userId == _seenUserId ? (_remote ?? _lastKnownGood) : null;" "_lastKnownGood = _remote ?? _lastKnownGood;"
run M10-report-every-time $FF/feature_flags.dart "if (_reported.add(id)) {" "if (_reported.add(id) || true) {"
run M11-zero-weight-wins $FF/bucketing.dart "cumulative += weights[i];
    if (bucket" "cumulative += weights[i];
    if (weights[i] == 0 && bucket < 5000 || bucket"
run M12-no-epoch-stream $FF/feature_flags.dart "if (session is SessionEpochs) {" "if (false) {"
run M13-no-notify-on-remote $FF/feature_flags.dart "_remote = snapshot;
      _notify();" "_remote = snapshot;"
echo finished
