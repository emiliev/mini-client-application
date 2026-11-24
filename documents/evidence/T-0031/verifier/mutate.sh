#!/bin/bash
# Usage: mutate.sh <name> <file> <perl-substitution> <targets...>
# Applies one perl -0pi substitution, checks it changed the file, runs the
# targets, prints which tests failed, and restores the file from git.
set -u
REPO=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a8c6bd698e60fb5fa
cd "$REPO"
name="$1"; file="$2"; subst="$3"; shift 3
cp "$file" /tmp/mc-T-0031-verifier-mut.bak
perl -0pi -e "$subst" "$file"
if cmp -s "$file" /tmp/mc-T-0031-verifier-mut.bak; then
  echo "[$name] MUTATION DID NOT APPLY"; exit 2
fi
out="$(tool/bazelw --output_base=/tmp/mc-ob-T-0031-verifier test --nocache_test_results "$@" 2>&1)"
rc=$?
cp /tmp/mc-T-0031-verifier-mut.bak "$file"
echo "[$name] bazel exit=$rc"
grep -E "^//.*(PASSED|FAILED|NO STATUS)" <<< "$out"
for t in "$@"; do
  p="${t#//}"; p="${p/://}"
  log="$REPO/bazel-testlogs/$p/test.log"
  [[ -f "$log" ]] && grep -E "^\s+FAIL\s|Some tests failed|[0-9]+ passed|[0-9]+ failed" "$log" | sed "s|^|  $t: |" | head -20
done
