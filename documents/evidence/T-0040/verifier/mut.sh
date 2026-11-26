#!/bin/bash
# T-0040 Verifier mutation runner (own scratch folder only).
# mut.sh <name> <file> <old> <new> <bazel targets...>
# Replaces exactly one occurrence of <old> in <file>, runs the targets uncached,
# reports KILLED (a test FAILED) or SURVIVED, then restores from a backup and
# checks the file matches HEAD.
set -uo pipefail
WT=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-adeb065bbdc8df91c
OB=/tmp/mc-ob-T-0040-verifier
LOGDIR=/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/T-0040-verifier/logs
mkdir -p "$LOGDIR"
name="$1"; file="$2"; old="$3"; new="$4"; shift 4
cd "$WT"
cp "$file" "$LOGDIR/backup.dart"
/usr/bin/python3 -I - "$file" "$old" "$new" <<'EOF'
import sys
p, old, new = sys.argv[1:4]
s = open(p).read()
n = s.count(old)
if n != 1:
    print(f"NOT APPLIED: {n} occurrences"); sys.exit(3)
open(p, "w").write(s.replace(old, new))
EOF
if [[ $? -ne 0 ]]; then echo "$name: NOT APPLIED"; exit 3; fi
log="$LOGDIR/$(tr -c 'a-zA-Z0-9' _ <<< "$name").log"
tool/bazelw --output_base="$OB" test --nocache_test_results --test_output=all "$@" > "$log" 2>&1
rc=$?
cp "$LOGDIR/backup.dart" "$file"
git diff --quiet -- "$file" || echo "RESTORE MISMATCH for $file"
fails=$(tr '\r' '\n' < "$log" | grep -a -E "^\s*(FAIL|\[E\])|Pixel test failed|Test failed|══╡ EXCEPTION" | sed 's/^ *//' | sort -u | head -12)
if tr '\r' '\n' < "$log" | grep -a -q "FAILED in\|FAILED TO BUILD\|Build did NOT complete"; then
  if tr '\r' '\n' < "$log" | grep -a -q "FAILED TO BUILD\|ERROR: .*Compil"; then
    echo "$name: BUILD ERROR (not a valid kill) rc=$rc"
  else
    echo "$name: KILLED rc=$rc"
  fi
else
  echo "$name: SURVIVED rc=$rc"
fi
echo "$fails" | head -12
