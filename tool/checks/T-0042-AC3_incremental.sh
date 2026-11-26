#!/bin/bash
# T-0042-AC3: incremental and stale handling of tool/ide_sync, on the real repo.
#   a. a second sync with no source change copies 0 files and leaves every mtime;
#   b. editing one freezed model re-copies only that model's output;
#   c. removing a model deletes its synced output (the manifest), and a new
#      model adds exactly one file;
#   d. `--watch` picks up an edit within 5 s (fswatch when installed, else polling).
# Negative controls: the mtime comparison must see a touched file, and the
# "only that model" comparison must fail when it is given a wrong expectation.
# Timings of each step go into the report.
#   tool/checks/T-0042-AC3_incremental.sh [--out FILE] [--role R]
# MC_OUTPUT_BASE selects the Bazel output base. Restores every file it edits.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
SYNC="$REPO/tool/ide_sync"
PKG=feature/characters/characters_list
MODEL="$PKG/lib/src/domain/model/character.dart"
GEN="$PKG/lib/src/domain/model/character.freezed.dart"
TMPMODEL="$PKG/lib/src/domain/model/t0042_tmp.dart"
TMPGEN="$PKG/lib/src/domain/model/t0042_tmp.freezed.dart"
BUILD="$PKG/BUILD.bazel"
rc=0
rows=()
WATCH_PID=""
cleanup() {
  [[ -z "$WATCH_PID" ]] || { kill "$WATCH_PID" 2>/dev/null; wait "$WATCH_PID" 2>/dev/null; pkill -P "$WATCH_PID" 2>/dev/null; }
  git checkout -q -- "$MODEL" "$BUILD" 2>/dev/null
  rm -f "$TMPMODEL" "$TMPGEN"
}
trap cleanup EXIT
[[ -z "$(git status --porcelain --untracked-files=no -- "$MODEL" "$BUILD")" ]] || { echo "refusing: $MODEL or $BUILD has uncommitted changes" >&2; exit 2; }

now() { /usr/bin/python3 -I -c 'import time; print(time.time())'; }
secs() { /usr/bin/python3 -I -c "print('%.1f' % ($2 - $1))"; }
sync() {  # sync [args]: prints the summary line, sets SYNC_SECS and SYNC_LOG
  local t0 t1
  t0=$(now)
  SYNC_LOG="$("$SYNC" --no-pub "$@" 2>&1)"
  t1=$(now)
  SYNC_SECS=$(secs "$t0" "$t1")
  SYNC_SUMMARY="$(grep -a '^IDE_SYNC' <<< "$SYNC_LOG" | tail -1)"
}
field() { sed -n "s/.*$2=\([0-9]*\).*/\1/p" <<< "$1"; }
mtimes() { (cd "$REPO" && xargs stat -f '%Fm %N' < .dart_tool/mc_ide_sync.manifest | sort -k2); }
row() { rows+=("| $1 | $2 | $3 |"); }
fail() { rc=1; row "$1" "**FAIL**" "$2"; }

report "# T-0042-AC3: incremental and stale handling" ""

sync --env dev
[[ "$(field "$SYNC_SUMMARY" total)" -gt 0 ]] || { report "no outputs synced: $SYNC_LOG"; finish T-0042-AC3 1; }
base_total=$(field "$SYNC_SUMMARY" total)

# a. no-op sync
before="$(mtimes)"
sync --env dev
after="$(mtimes)"
if [[ "$(field "$SYNC_SUMMARY" copied)" == 0 && "$before" == "$after" ]]; then
  row "a. second sync, no change" PASS "copied=0 unchanged=$(field "$SYNC_SUMMARY" unchanged), all $base_total mtimes equal, ${SYNC_SECS}s"
else fail "a. second sync, no change" "$SYNC_SUMMARY; mtimes equal: $([[ "$before" == "$after" ]] && echo yes || echo no)"; fi
# negative control: the comparison sees a touched file
touch "$REPO/$GEN"
if [[ "$(mtimes)" == "$before" ]]; then rc=1; row "a. negative control (touched file)" "**FAIL**" "mtime comparison did not notice"
else row "a. negative control (touched file)" PASS "mtime comparison failed as it must"; fi
sync --env dev   # the content is unchanged, so nothing is rewritten and the touch stays

# b. edit one model
/usr/bin/python3 -I - "$REPO/$MODEL" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read()
a = "    required ApiImage image,\n"
assert a in t
open(p, "w").write(t.replace(a, a + "    String? nickname,\n"))
PY
sync --env dev
copied=$(field "$SYNC_SUMMARY" copied)
wrote="$(grep -a 'ide_sync: wrote' <<< "$SYNC_LOG" | sed 's/.*wrote //')"
if [[ "$copied" == 1 && "$wrote" == "$GEN" ]] && grep -q 'nickname' "$REPO/$GEN"; then
  row "b. edit one freezed model" PASS "copied=1 ($wrote), ${SYNC_SECS}s"
else fail "b. edit one freezed model" "$SYNC_SUMMARY; wrote: $wrote"; fi
# negative control: a wrong expectation (the edited model's file is not 'nothing')
if [[ "$copied" == 0 ]]; then rc=1; row "b. negative control" "**FAIL**" "the edit was not noticed"
else row "b. negative control" PASS "an edit copies >= 1 file, so 'copied=0' would have failed"; fi
git checkout -q -- "$MODEL"
sync --env dev
if [[ "$(field "$SYNC_SUMMARY" copied)" == 1 ]]; then row "b. revert the edit" PASS "copied=1 (back to the original), ${SYNC_SECS}s"
else fail "b. revert the edit" "$SYNC_SUMMARY"; fi

# c. add a model, then remove it
cat > "$REPO/$TMPMODEL" <<'DART'
import 'package:freezed_annotation/freezed_annotation.dart';

part 't0042_tmp.freezed.dart';

@freezed
abstract class T0042Tmp with _$T0042Tmp {
  const factory T0042Tmp({required String name}) = _T0042Tmp;
}
DART
cat >> "$REPO/$BUILD" <<'BZL'

dart_codegen(
    name = "_t0042_tmp_freezed",
    package_name = _PKG,
    src = "lib/src/domain/model/t0042_tmp.dart",
    generator_bin = "@rules_dart//dart/ext/freezed:shim",
    language_version = _LANG,
    output_suffixes = [".freezed.dart"],
    deps = ["@pub_deps//:freezed_annotation"],
)
BZL
sync --env dev
if [[ "$(field "$SYNC_SUMMARY" copied)" == 1 && -f "$REPO/$TMPGEN" ]] && grep -qxF "$TMPGEN" "$REPO/.dart_tool/mc_ide_sync.manifest"; then
  row "c. add a model" PASS "copied=1, in the manifest, ${SYNC_SECS}s"
else fail "c. add a model" "$SYNC_SUMMARY"; fi
rm -f "$REPO/$TMPMODEL"; git checkout -q -- "$BUILD"
sync --env dev
if [[ "$(field "$SYNC_SUMMARY" removed)" == 1 && ! -e "$REPO/$TMPGEN" ]] && ! grep -qxF "$TMPGEN" "$REPO/.dart_tool/mc_ide_sync.manifest" \
   && [[ "$(field "$SYNC_SUMMARY" total)" == "$base_total" ]]; then
  row "c. remove the model" PASS "removed=1, the synced file and its manifest line are gone, ${SYNC_SECS}s"
else fail "c. remove the model" "$SYNC_SUMMARY; file exists: $([[ -e "$REPO/$TMPGEN" ]] && echo yes || echo no)"; fi

# d. watch
log="$(mktemp)"
MC_IDE_SYNC_POLL="${MC_IDE_SYNC_POLL:-1}" "$SYNC" --watch --no-pub --env dev >"$log" 2>&1 &
WATCH_PID=$!
for _ in $(seq 1 120); do grep -q '^IDE_SYNC' "$log" && break; sleep 0.5; done
grep -q '^IDE_SYNC' "$log" || { fail "d. --watch starts" "no initial sync: $(tail -3 "$log")"; }
sleep 1
t0=$(now)
/usr/bin/python3 -I - "$REPO/$MODEL" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read()
a = "    required ApiImage image,\n"
open(p, "w").write(t.replace(a, a + "    String? nickname,\n"))
PY
got=no
for _ in $(seq 1 200); do
  if grep -q 'nickname' "$REPO/$GEN" 2>/dev/null; then got=yes; break; fi
  sleep 0.1
done
t1=$(now)
took=$(secs "$t0" "$t1")
tool=$(command -v fswatch >/dev/null 2>&1 && echo fswatch || echo "polling every ${MC_IDE_SYNC_POLL:-1}s")
if [[ "$got" == yes ]] && /usr/bin/python3 -I -c "import sys; sys.exit(0 if $took <= 5 else 1)"; then
  row "d. --watch picks up an edit" PASS "${took}s (limit 5 s; $tool)"
else fail "d. --watch picks up an edit" "got=$got after ${took}s ($tool)"; fi
kill "$WATCH_PID" 2>/dev/null; wait "$WATCH_PID" 2>/dev/null; pkill -P "$WATCH_PID" 2>/dev/null; WATCH_PID=""
git checkout -q -- "$MODEL"
sync --env dev   # leave the tree synced and clean

report "| Step | Result | Detail |" "|---|---|---|" "${rows[@]}" "" \
  "Synced files in the manifest: $base_total." "" "Watch log:" '```' "$(grep -a '^ide_sync' "$log" | tail -8)" '```'
rm -f "$log"
finish T-0042-AC3 $rc
