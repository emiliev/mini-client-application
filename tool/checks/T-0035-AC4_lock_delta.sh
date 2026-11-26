#!/bin/bash
# pre-merge only, pinned to 6e7eaaf: historical one-off, no longer run by T-0035-AC4_gates.sh.
# T-0035-AC4 (one-off): the only lock change is flow_builder's source. Pinned
# to the commit T-0035 branched from (6e7eaaf), so it is valid on the T-0035
# branch before it merges, and says so (does not compare with origin/main,
# which moves). After the merge, T-0035-AC4_provenance.sh is the standing check.
#   1. pubspec.lock equals the base's minus the `flow_builder:` block;
#   2. MODULE.bazel.lock differs from the base's only by the removal of the
#      `pub_deps__flow_builder` repo and its mentions, plus the one changed
#      `FILE:@@//pubspec.lock <hash>` line.
#   tool/checks/T-0035-AC4_lock_delta.sh [--out FILE] [--role R]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
BASE=6e7eaaf
ok=1
if ! git cat-file -e "$BASE^{commit}" 2>/dev/null; then
  report "# T-0035-AC4: lock delta" "" "Base commit $BASE is not in this clone."
  finish T-0035-AC4-lock-delta 1
fi
strip() { awk '/^  flow_builder:$/{skip=1; next} skip&&/^  [a-z_]+:$/{skip=0} !skip'; }
git show "$BASE:pubspec.lock" | grep -q '^  flow_builder:$' || ok=0   # positive control
lockdiff=$(diff <(git show "$BASE:pubspec.lock" | strip) pubspec.lock 2>&1); lock_rc=$?
grep -q '^  flow_builder:$' pubspec.lock && ok=0

# MODULE.bazel.lock, structurally: with every key and list entry that names
# flow_builder removed and the pubspec.lock hash blanked, base and current must
# be equal; the base must have had flow_builder, the current must not.
mod=$(/usr/bin/python3 -I - "$BASE" <<'EOF'
import json, subprocess, sys
base = json.loads(subprocess.check_output(["git", "show", sys.argv[1] + ":MODULE.bazel.lock"]))
cur = json.load(open("MODULE.bazel.lock"))
def scrub(o):
    if isinstance(o, dict):
        return {k: scrub(v) for k, v in o.items() if "flow_builder" not in k}
    if isinstance(o, list):
        return [scrub(v) for v in o if not (isinstance(v, str) and "flow_builder" in v)]
    if isinstance(o, str) and o.startswith("FILE:@@//pubspec.lock "):
        return "FILE:@@//pubspec.lock"
    return o
had = "flow_builder" in json.dumps(base)
gone = "flow_builder" not in json.dumps(cur)
print("equal" if scrub(base) == scrub(cur) and had and gone else "DIFFERS")
EOF
)
report "# T-0035-AC4: lock delta against base $BASE (one-off)" "" "| Check | Result | Required |" "|---|---|---|" \
  "| pubspec.lock = base minus the flow_builder block | $([[ $lock_rc -eq 0 ]] && echo identical || echo "DIFFERS: $(head -5 <<< "$lockdiff")") | identical |" \
  "| MODULE.bazel.lock = base minus the flow_builder repo and mentions | $mod | equal |"
[[ $lock_rc -eq 0 && "$mod" == equal ]] || ok=0
finish T-0035-AC4-lock-delta $([[ $ok -eq 1 ]] && echo 0 || echo 1)
