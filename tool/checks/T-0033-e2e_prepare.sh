#!/bin/bash
# T-0033 (D1): tool/e2e/prepare_pub_project.sh works from a fresh Bazel output
# base, copies exactly the generated files the app's targets make, and never a
# stale generated file left in the working tree or any runfiles/symlink junk.
#   tool/checks/T-0033-e2e_prepare.sh [--out FILE]
# Environment: MC_FRESH_OUTPUT_BASE (default /tmp/mc-ob-T-0033-fresh) is wiped
# first and shut down at the end, so the first build is cold.
# Negative controls (the verify step must FAIL): a stale generated file in the
# copy, and a junk generated-looking file in the copy.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
rc=0
FRESH="${MC_FRESH_OUTPUT_BASE:-/tmp/mc-ob-T-0033-fresh}"
SCR="$(mktemp -d)"
PLANT="utility/mc_prelude/lib/src/stale_planted.g.dart"
cleanup() {
  rm -f "$REPO/$PLANT"
  "$BAZELW" --output_base="$FRESH" shutdown >/dev/null 2>&1
  rm -rf "$SCR"
}
trap cleanup EXIT

report "# T-0033 e2e prepare: fresh output base, no stale or junk files" ""
"$BAZELW" --output_base="$FRESH" shutdown >/dev/null 2>&1
rm -rf "$FRESH"
printf '// planted by T-0033-e2e_prepare.sh; an older build could have left this\n' >"$REPO/$PLANT"
git check-ignore -q "$PLANT" || { report "the planted file is not git-ignored: the check is invalid"; finish T-0033-e2e_prepare 1; }

log="$SCR/prepare.log"
MC_OUTPUT_BASE="$FRESH" tool/e2e/prepare_pub_project.sh --app app/mini_client --out "$SCR/p" >"$log" 2>&1
prep_rc=$?
report "## prepare from a fresh output base ($FRESH): exit $prep_rc" '```' "$(grep -E '^(==>|GENERATED_FILES|E2E_PROJECT)' "$log")" '```'
[[ "$prep_rc" == 0 ]] || { report '```' "$(tail -20 "$log")" '```'; finish T-0033-e2e_prepare 1; }
expected="$(sed -n 's/^GENERATED_FILES=//p' "$log")"
OUTDIR="$SCR/p"

# verify <dir> <expected count>: prints problems, returns 1 when any.
verify() {
  local dir=$1 want=$2 bad=0 have
  have="$(cd "$dir" && find app feature utility \( -type f -o -type l \) \
    \( -name '*.g.dart' -o -name '*.freezed.dart' -o -name '*.config.dart' \
       -o -path '*/lib/src/l10n/*_l10n*.dart' \) | wc -l | tr -d ' ')"
  [[ "$have" == "$want" ]] || { echo "generated-looking files: $have, built outputs: $want"; bad=1; }
  [[ ! -e "$dir/$PLANT" ]] || { echo "stale file copied: $PLANT"; bad=1; }
  [[ ! -e "$dir/documents" ]] || { echo "documents/ copied"; bad=1; }
  # shellcheck disable=SC2144
  compgen -G "$dir/bazel-*" >/dev/null && { echo "a bazel-* symlink was copied"; bad=1; }
  for f in feature/characters/characters_list/lib/src/di/di_initializer.config.dart \
           app/wiring/universe_wiring/lib/src/routes/characters_routes.g.dart \
           app/mini_client/lib/src/router/app_routes.g.dart; do
    [[ -s "$dir/$f" ]] || { echo "missing generated file: $f"; bad=1; }
  done
  return "$bad"
}

problems="$(verify "$OUTDIR" "$expected")"
if [[ -z "$problems" ]]; then
  report "## verify: PASS ($expected generated files, exactly the built outputs; the planted stale \`$PLANT\` was not copied)"
else
  report "## verify: FAIL" '```' "$problems" '```'
  rc=1
fi

# Negative controls: the same verify step must fail on a dirty copy.
cp "$REPO/$PLANT" "$OUTDIR/$PLANT"
if verify "$OUTDIR" "$expected" >/dev/null; then
  report "## negative control (stale file in the copy): verify PASSED, so it proves nothing"
  rc=1
else
  report "## negative control (stale file in the copy): verify FAILED as it must"
fi
rm -f "$OUTDIR/$PLANT"
printf 'x\n' >"$OUTDIR/app/mini_client/lib/junk.g.dart"
if verify "$OUTDIR" "$expected" >/dev/null; then
  report "## negative control (junk generated-looking file): verify PASSED, so it proves nothing"
  rc=1
else
  report "## negative control (junk generated-looking file): verify FAILED as it must"
fi
finish T-0033-e2e_prepare $rc
