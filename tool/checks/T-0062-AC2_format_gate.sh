#!/bin/bash
# T-0062-AC2 (P-101, P-111): the shared format gate (tool/checks/lib/format_gate.sh)
# passes in a brand-new worktree and covers exactly the repo's own Dart.
#   0. control: in a fresh worktree (no .dart_tool) a bare `dart format` reports
#      false changes, so the pub get step is what makes the gate pass.
#   1. the gate passes there, running `fvm dart pub get --offline` itself.
#   2. negative control 1: an unformatted line in tool/loc fails the gate.
#   3. negative control 2: an unformatted line in third_party/flow_builder and a
#      `.dart` file under documents/ do not fail it.
#   4. the flow_builder provenance check fails while the line is there (it sees
#      the file) and passes once the line is reverted.
# Works in a throwaway worktree of HEAD (commit first) and always removes it.
#   tool/checks/T-0062-AC2_format_gate.sh [--out FILE] [--role R]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
WT="$(mktemp -d "${TMPDIR:-/tmp}/mc-T-0062-$ROLE-wt.XXXXXX")"
rmdir "$WT"
cleanup() {
  git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
  rm -rf "$WT"
  git -C "$REPO" worktree prune
}
trap cleanup EXIT
rc=0
fail() { report "- **FAIL**: $*"; rc=1; }
BAD='void   zzUnformatted( ){ }'

git -C "$REPO" worktree add --detach "$WT" HEAD >/dev/null 2>&1 || { echo "cannot create the worktree" >&2; exit 2; }
report "# T-0062-AC2: the format gate in a fresh worktree" "" \
  "Worktree: \`$WT\` (detached at \`$(git -C "$REPO" rev-parse --short HEAD)\`), removed at the end." ""
if [[ ! -e "$WT/.dart_tool" ]]; then report "- fresh: no \`.dart_tool\` in the worktree"; else fail "the worktree already has .dart_tool"; fi
GATE="$WT/tool/checks/lib/format_gate.sh"

# 0. control
n="$(cd "$WT" && fvm dart format --output=none app feature utility spike tool 2>&1 | grep -c '^Changed ')"
if [[ "$n" -gt 0 ]]; then
  report "- control: a bare \`dart format\` with no \`.dart_tool\` reports $n false changes"
else
  fail "control: a bare dart format in a fresh worktree reported no change, so the pub get step is not proven"
fi
rm -rf "$WT/.dart_tool"

# 1. the gate passes, getting pub get by itself.
out="$("$GATE" 2>&1)"; grc=$?
if [[ $grc == 0 ]]; then
  report "- the gate passes in the fresh worktree: \`$(grep -a '^Formatted' <<< "$out" | tail -1)\`"
else
  fail "the gate fails in a fresh worktree (exit $grc)"; report '```' "$(tail -8 <<< "$out")" '```'
fi
if grep -aq 'running .fvm dart pub get --offline' <<< "$out"; then report "- it ran \`fvm dart pub get --offline\` itself"; else fail "the gate did not run pub get"; fi
[[ -f "$WT/.dart_tool/package_config.json" ]] || fail "no package_config.json after the gate"

# 2. negative control 1
printf '%s\n' "$BAD" >> "$WT/tool/loc/lib/count.dart"
if "$GATE" >/dev/null 2>&1; then
  fail "negative control 1: an unformatted line in tool/loc did not fail the gate"
else
  report "- negative control 1: an unformatted line in \`tool/loc/lib/count.dart\` fails the gate"
fi
git -C "$WT" checkout -- tool/loc/lib/count.dart

# 3. negative control 2
printf '%s\n' "$BAD" >> "$WT/third_party/flow_builder/lib/flow_builder.dart"
printf '%s\n' "$BAD" > "$WT/documents/zz_probe.dart"
if "$GATE" >/dev/null 2>&1; then
  report "- negative control 2: an unformatted line in \`third_party/flow_builder\` and a \`.dart\` file under \`documents/\` do not fail the gate"
else
  fail "negative control 2: third_party or documents made the gate fail"
fi
rm -f "$WT/documents/zz_probe.dart"

# 4. provenance
if "$WT/tool/checks/T-0035-AC4_provenance.sh" >/dev/null 2>&1; then
  fail "provenance control: the check passed with a modified flow_builder"
else
  report "- provenance control: with the line added to flow_builder the provenance check fails (it sees the file, so a format run there would be noticed)"
fi
git -C "$WT" checkout -- third_party/flow_builder/lib/flow_builder.dart
prov="$("$WT/tool/checks/T-0035-AC4_provenance.sh" 2>&1)"; prc=$?
if [[ $prc == 0 ]]; then
  report "- after the revert the flow_builder provenance check passes: \`$(grep -a -m1 'PASS' <<< "$prov")\`"
else
  fail "the flow_builder provenance check fails"; report '```' "$(tail -8 <<< "$prov")" '```'
fi
if [[ -z "$(git -C "$WT" status --porcelain)" ]]; then
  report "- the worktree is clean after the controls (pub get leaves no tracked change)"
else
  fail "the worktree is not clean: $(git -C "$WT" status --short | head -3 | tr '\n' ' ')"
fi
finish T-0062-AC2 "$rc"
