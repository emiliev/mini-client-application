#!/bin/bash
# T-0042-AC5: tests of tool/ide_sync's own logic, with fixtures (no Bazel).
# MC_IDE_SYNC_LIST replaces the Bazel query/build/cquery with a list of
# "<source>\t<dest>" lines, and MC_IDE_SYNC_ROOT points the script at a scratch
# git repository that carries this repo's .gitignore, so the guards run against
# the real ignore rules.
#   tool/checks/T-0042-AC5_script_tests.sh [--out FILE] [--role R]
# Negative control: the harness's own `expect` must fail on a wrong expectation.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
SYNC="$REPO/tool/ide_sync"
T="$(mktemp -d)"
trap 'rm -rf "$T"; [[ -z "${WPID:-}" ]] || { kill "$WPID" 2>/dev/null; pkill -P "$WPID" 2>/dev/null; }' EXIT
rows=()
rc=0
expect() {  # expect <name> <command...>: PASS when the command succeeds
  local name=$1; shift
  if "$@" >/dev/null 2>&1; then rows+=("| $name | PASS |"); else rows+=("| $name | **FAIL** |"); rc=1; fi
}
field() { sed -n "s/.*$2=\([0-9]*\).*/\1/p" <<< "$1" | tail -1; }

# A scratch repository: the real .gitignore, a few tracked files, and a "bazel-out".
new_repo() {  # new_repo <name>: prints the directory
  local r="$T/$1"
  mkdir -p "$r/app/mini_client/lib" "$r/feature/f/lib/src/domain" "$r/feature/f/lib/src/l10n" "$r/utility/u/lib" "$T/$1-out"
  cp "$REPO/.gitignore" "$r/.gitignore"
  printf 'name: mini_client\nflutter:\n  assets:\n    - assets/app_config.json\n' >"$r/app/mini_client/pubspec.yaml"
  mkdir -p "$r/app/mini_client/ios/Runner"
  printf 'class A {}\n' >"$r/feature/f/lib/f.dart"
  printf 'class U {}\n' >"$r/utility/u/lib/u.dart"
  (cd "$r" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm init)
  echo "$r"
}
out() { echo "$T/$1-out"; }  # the fixture "bazel-out" of repo <name>
mk() {  # mk <repo name> <file name in out> <dest> <content>: add to the list
  local d; d="$(out "$1")"
  printf '%s\n' "$4" >"$d/$2"
  printf '%s\t%s\n' "$d/$2" "$3" >>"$d/list.tsv"
}
run() {  # run <repo name> [args]: runs ide_sync on the fixture, sets LOG, RC and SUM
  local n=$1; shift
  LOG="$(MC_IDE_SYNC_ROOT="$T/$n" MC_IDE_SYNC_LIST="$(out "$n")/list.tsv" MC_IDE_SYNC_NO_IOS=1 "$SYNC" --no-pub "$@" 2>&1)"
  RC=$?
  SUM="$(grep -a '^IDE_SYNC' <<< "$LOG" | tail -1)"
}
mt() { stat -f '%Fm' "$1"; }

report "# T-0042-AC5: tool/ide_sync script tests (fixtures)" ""

# --- harness negative control ------------------------------------------------------
if ( expect "inner" test 1 = 2 >/dev/null; [[ $rc == 1 ]] ); then rows+=("| harness negative control: expect() fails on a wrong expectation | PASS |")
else rows+=("| harness negative control | **FAIL** |"); rc=1; fi

# --- 1. first sync, 2. second sync is a no-op --------------------------------------
R="$(new_repo basic)"
mk basic a.freezed "feature/f/lib/src/domain/a.freezed.dart" "// a v1"
mk basic a.g "feature/f/lib/src/domain/a.g.dart" "// a.g"
mk basic di "feature/f/lib/src/di/di_initializer.config.dart" "// di"
mk basic l10n "feature/f/lib/src/l10n/f_l10n.dart" "// l10n"
run basic
[[ "$RC" = 0 && "$(field "$SUM" copied)" = 4 ]] && rows+=("| 1. first sync copies every output (copied=4) | PASS |") || { rows+=("| 1. first sync copies every output | **FAIL**: $SUM |"); rc=1; }
expect "1. the copies hold the source bytes" cmp -s "$(out basic)/a.freezed" "$R/feature/f/lib/src/domain/a.freezed.dart"
expect "1. the copies are writable (Bazel outputs are read-only)" test -w "$R/feature/f/lib/src/domain/a.freezed.dart"
expect "1. the manifest lists the 4 files, sorted" test "$(wc -l <"$R/.dart_tool/mc_ide_sync.manifest" | tr -d ' ')" = 4
expect "1. the manifest is sorted" bash -c "sort -c '$R/.dart_tool/mc_ide_sync.manifest'"
expect "1. git status is clean after the sync" test -z "$(cd "$R" && git status --porcelain)"
m1="$(mt "$R/feature/f/lib/src/domain/a.freezed.dart")"
sleep 1.1
run basic
[[ "$RC" = 0 && "$(field "$SUM" copied)" = 0 && "$(field "$SUM" unchanged)" = 4 ]] && rows+=("| 2. second sync copies 0 files (unchanged=4) | PASS |") || { rows+=("| 2. second sync copies 0 files | **FAIL**: $SUM |"); rc=1; }
expect "2. mtimes are unchanged" test "$(mt "$R/feature/f/lib/src/domain/a.freezed.dart")" = "$m1"

# --- 3. one change re-copies one file ---------------------------------------------------
printf '// a v2\n' >"$(out basic)/a.freezed"
run basic
[[ "$(field "$SUM" copied)" = 1 && "$(field "$SUM" unchanged)" = 3 ]] && rows+=("| 3. a changed output re-copies only that file | PASS |") || { rows+=("| 3. a changed output re-copies only that file | **FAIL**: $SUM |"); rc=1; }
expect "3. the new bytes are in place" grep -q 'a v2' "$R/feature/f/lib/src/domain/a.freezed.dart"

# --- 4. stale: dropped from the list is deleted ----------------------------------------
grep -v 'a\.g\b' "$(out basic)/list.tsv" >"$(out basic)/list.new" && mv "$(out basic)/list.new" "$(out basic)/list.tsv"
run basic
[[ "$(field "$SUM" removed)" = 1 && ! -e "$R/feature/f/lib/src/domain/a.g.dart" ]] && rows+=("| 4. a file no longer produced is deleted | PASS |") || { rows+=("| 4. a file no longer produced is deleted | **FAIL**: $SUM |"); rc=1; }
expect "4. and leaves the manifest" bash -c "! grep -q 'a.g.dart' '$R/.dart_tool/mc_ide_sync.manifest'"
expect "4. the other outputs stay" test -f "$R/feature/f/lib/src/domain/a.freezed.dart"

# --- 5. guards: a tracked destination -----------------------------------------------------
G="$(new_repo guard)"
printf '// committed\n' >"$G/feature/f/lib/src/domain/b.g.dart"
(cd "$G" && git add -f feature/f/lib/src/domain/b.g.dart && git -c user.email=t@t -c user.name=t commit -qm "tracked generated file")
mk guard b "feature/f/lib/src/domain/b.g.dart" "// from bazel"
mk guard ok "feature/f/lib/src/domain/ok.freezed.dart" "// ok"
run guard
expect "5. a tracked destination is refused (exit 1)" test "$RC" = 1
expect "5. REFUSED names the file" grep -q 'REFUSED: feature/f/lib/src/domain/b.g.dart is tracked' <<< "$LOG"
expect "5. nothing is written when any path is refused" test ! -e "$G/feature/f/lib/src/domain/ok.freezed.dart"
expect "5. the tracked file keeps its content" grep -q committed "$G/feature/f/lib/src/domain/b.g.dart"

# --- 6. guards: a path git would pick up -----------------------------------------------------
H="$(new_repo notignored)"
mk notignored x "feature/f/lib/src/domain/plain_name.dart" "// not a generated name"
run notignored
expect "6. a destination that is not git-ignored is refused" test "$RC" = 1
expect "6. REFUSED says a commit would pick it up" grep -q 'is not git-ignored' <<< "$LOG"
expect "6. and nothing is written" test ! -e "$H/feature/f/lib/src/domain/plain_name.dart"

# --- 7. the R28 fallback manifest ---------------------------------------------------------------
F="$(new_repo fallback)"
mk fallback c "feature/f/lib/src/domain/c.g.dart" "// bazel c"
mk fallback d "feature/f/lib/src/domain/d.g.dart" "// bazel d"
printf 'generators:\n  - retrofit\noutputs:\n  - feature/f/lib/src/domain/c.g.dart\n' >"$T/fallback.yaml"
LOG="$(MC_IDE_SYNC_FALLBACK="$T/fallback.yaml" MC_IDE_SYNC_ROOT="$F" MC_IDE_SYNC_LIST="$(out fallback)/list.tsv" MC_IDE_SYNC_NO_IOS=1 "$SYNC" --no-pub 2>&1)"; RC=$?
SUM="$(grep -a '^IDE_SYNC' <<< "$LOG" | tail -1)"
expect "7. a path in the R28 fallback manifest is not written" test ! -e "$F/feature/f/lib/src/domain/c.g.dart"
expect "7. the other path is" test -f "$F/feature/f/lib/src/domain/d.g.dart"
expect "7. skipped=1" test "$(field "$SUM" skipped)" = 1
expect "7. the fallback path is not in the manifest" bash -c "! grep -q 'c.g.dart' '$F/.dart_tool/mc_ide_sync.manifest'"

# --- 8. --link ----------------------------------------------------------------------------------------
L="$(new_repo link)"
mk link e "feature/f/lib/src/domain/e.g.dart" "// e"
run link --link
expect "8. --link makes a symlink to the Bazel output" test "$(readlink "$L/feature/f/lib/src/domain/e.g.dart")" = "$(out link)/e"
run link --link
expect "8. a second --link sync changes nothing" test "$(field "$SUM" copied)" = 0
run link
expect "8. copy mode replaces the link by a regular file" bash -c "[ -f '$L/feature/f/lib/src/domain/e.g.dart' ] && [ ! -L '$L/feature/f/lib/src/domain/e.g.dart' ]"

# --- 9. package scope ---------------------------------------------------------------------------------------
S="$(new_repo scope)"
mk scope f1 "feature/f/lib/src/domain/f1.g.dart" "// f1"
mk scope u1 "utility/u/lib/u1.g.dart" "// u1"
run scope
cp "$(out scope)/list.tsv" "$(out scope)/list.full"
grep 'feature/f/' "$(out scope)/list.full" >"$(out scope)/list.tsv"   # u1 is no longer produced...
run scope feature/f
expect "9. a scoped sync keeps manifest entries of other packages" grep -q 'utility/u/lib/u1.g.dart' "$S/.dart_tool/mc_ide_sync.manifest"
expect "9. and does not delete files outside its scope" test -f "$S/utility/u/lib/u1.g.dart"
run scope
expect "9. a full sync deletes it (not produced any more)" test ! -e "$S/utility/u/lib/u1.g.dart"
run scope feature/f/ "//feature/f/..."
expect "9. package arguments accept a trailing slash and //pkg/..." test "$RC" = 0

# --- 10. a tracked file listed in the manifest is never deleted -------------------------------------------
printf 'feature/f/lib/f.dart\n' >>"$S/.dart_tool/mc_ide_sync.manifest"
run scope
expect "10. a tracked file in the manifest is not deleted" test -f "$S/feature/f/lib/f.dart"

# --- 11. --clean -------------------------------------------------------------------------------------------------
C="$(new_repo clean)"
mk clean g "feature/f/lib/src/domain/g.g.dart" "// g"
run clean
LOG="$(MC_IDE_SYNC_ROOT="$C" "$SYNC" --clean 2>&1)"
expect "11. --clean deletes the synced files and the manifest" bash -c "[ ! -e '$C/feature/f/lib/src/domain/g.g.dart' ] && [ ! -e '$C/.dart_tool/mc_ide_sync.manifest' ]"
expect "11. --clean keeps tracked sources" test -f "$C/feature/f/lib/f.dart"

# --- 12. --env writes the config asset; without --env it is kept --------------------------------------------------
E="$(new_repo env)"
mk env h "feature/f/lib/src/domain/h.g.dart" "// h"
run env --env dev
expect "12. --env dev writes app/mini_client/assets/app_config.json" cmp -s "$REPO/tool/bazel/config/dev.json" "$E/app/mini_client/assets/app_config.json"
expect "12. the asset is git-ignored (git status clean)" test -z "$(cd "$E" && git status --porcelain)"
run env
expect "12. a run without --env keeps the asset" test -f "$E/app/mini_client/assets/app_config.json"
expect "12. and keeps it in the manifest" grep -q 'assets/app_config.json' "$E/.dart_tool/mc_ide_sync.manifest"
run env --env e2e
expect "12. --env e2e switches the asset to e2e.json" cmp -s "$REPO/tool/bazel/config/e2e.json" "$E/app/mini_client/assets/app_config.json"
run env --env nonexistent
expect "12. an unknown environment is refused (exit 2)" test "$RC" = 2

# --- 13. arguments ---------------------------------------------------------------------------------------------------
run env --bogus
expect "13. an unknown option is refused (exit 2)" test "$RC" = 2
run env no/such/package
expect "13. an unknown package is refused (exit 2)" test "$RC" = 2

# --- 14. --watch ----------------------------------------------------------------------------------------------------------
W="$(new_repo watch)"
mk watch w "feature/f/lib/src/domain/w.g.dart" "// w v1"
(MC_IDE_SYNC_ROOT="$W" MC_IDE_SYNC_LIST="$(out watch)/list.tsv" MC_IDE_SYNC_NO_IOS=1 MC_IDE_SYNC_POLL=1 "$SYNC" --watch --no-pub >"$T/watch.log" 2>&1) &
WPID=$!
disown "$WPID"
for _ in $(seq 1 50); do [[ -f "$W/feature/f/lib/src/domain/w.g.dart" ]] && break; sleep 0.2; done
sleep 1.2
printf '// w v2\n' >"$(out watch)/w"                      # what Bazel would now produce
printf 'class A { int x = 1; }\n' >"$W/feature/f/lib/f.dart"   # the source edit that triggers it
ok=no
for _ in $(seq 1 50); do grep -q 'w v2' "$W/feature/f/lib/src/domain/w.g.dart" 2>/dev/null && { ok=yes; break; }; sleep 0.1; done
expect "14. --watch re-syncs within 5 s of a source edit" test "$ok" = yes
kill "$WPID" 2>/dev/null; pkill -P "$WPID" 2>/dev/null; WPID=""

report "| Test | Result |" "|---|---|" "${rows[@]}"
finish T-0042-AC5-script-tests $rc
