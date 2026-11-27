#!/bin/bash
# T-0036 Verifier, re-verification at cbadeb0: install the probes (kit + the
# exemplar), optionally revert flow_builder patch change 4 (both halves, or one),
# run, restore.
#   run_rv.sh head|nohunk4|no_postframe|no_alwaysscope [extra bazel targets...]
set -uo pipefail
MODE="$1"; shift
S="$(cd "$(dirname "$0")" && pwd)"
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a9c18a5ca6a657e99
cd "$W" || exit 2
FF=utility/mc_feature_flow
CL=feature/characters/characters_list
FB=third_party/flow_builder/lib/flow_builder.dart
restore() {
  git -C "$W" checkout -- "$FF" "$CL" "$FB"
  rm -f "$FF/test/verifier_probe_test.dart" "$CL/test/verifier_probe_test.dart"
}
trap restore EXIT
cat "$S/ff_build_append.txt" >> "$FF/BUILD.bazel"
cat "$S/cl_build_append.txt" >> "$CL/BUILD.bazel"
cp "$S/rv_probe_test.dart.txt" "$FF/test/verifier_probe_test.dart"
cp "$S/characters_probe_test.dart.txt" "$CL/test/verifier_probe_test.dart"
/usr/bin/python3 -I - "$FB" "$MODE" <<'PY' || exit 2
import sys
p, mode = sys.argv[1:3]
s = open(p).read()
post = """    // mini-client T-0036: `_canPop` reads the navigator, which still holds the
    // old routes while this build runs. After a state update that returns to
    // the root, `PopScope(canPop: false)` would stay mounted and eat the next
    // pop, so recompute once the navigator has the new pages (see VENDORED.md).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
"""
scope_new = "    return PopScope(canPop: !condition, child: child);"
scope_old = "    return condition ? PopScope(canPop: false, child: child) : child;"
assert post in s and scope_new in s
if mode in ("nohunk4", "no_postframe"):
    s = s.replace(post, "")
if mode in ("nohunk4", "no_alwaysscope"):
    s = s.replace(scope_new, scope_old)
open(p, "w").write(s)
PY
tool/bazelw --output_base=/tmp/mc-ob-T-0036-verifier test --nocache_test_results --test_output=all \
  //$FF:verifier_probe_test //$CL:verifier_probe_test //$FF:flow_kit_test "$@" > "$S/rv_$MODE.raw.log" 2>&1
echo "bazel rc=$?"
tr '\r' '\n' < "$S/rv_$MODE.raw.log" \
  | grep -a -E "^(R[0-9]|P[0-9])|  (PASS|FAIL) |Expected:|Actual:|PASSED|FAILED|Executed|rror -" \
  | grep -av '^\['
