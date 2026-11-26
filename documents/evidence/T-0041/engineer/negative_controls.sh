#!/bin/bash
# T-0041 negative controls: each evidence script must FAIL when it cannot
# prove its claim. Every control plants one defect, runs the check, expects a
# non-zero exit, and restores the file (verified with `git diff --quiet`).
# REFUSES to run when a file it changes has uncommitted edits.
#
#   MC_TASK=T-0041 MC_ROLE=engineer documents/evidence/T-0041/engineer/negative_controls.sh
#
# Writes each check's report to documents/evidence/$MC_TASK/$MC_ROLE/neg-*.md.
# Exit 0 only if every check failed as it should.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
: "${MC_TASK:?set MC_TASK (e.g. T-0041)}"
: "${MC_ROLE:?set MC_ROLE (engineer or verifier)}"
export MC_BAZEL_STARTUP="--output_base=/tmp/mc-ob-$MC_TASK-$MC_ROLE"
EV="documents/evidence/$MC_TASK/$MC_ROLE"
PKG=feature/comics/comics_details
DTO=$PKG/lib/src/domain/model/comic_dto.dart
BUILD=$PKG/BUILD.bazel
FILES=("$DTO" "$BUILD")
for f in "${FILES[@]}"; do
  if ! git diff --quiet -- "$f" || ! git diff --cached --quiet -- "$f"; then
    echo "REFUSING TO RUN: $f has uncommitted edits"; exit 2
  fi
done
FAKE="$PKG/lib/src/domain/model/planted.g.dart"
cleanup() {
  git checkout -- "${FILES[@]}"
  git rm -q --cached --ignore-unmatch "$FAKE" > /dev/null 2>&1
  rm -f "$FAKE"
}
trap cleanup EXIT
rc=0

# expect_fail <name> <file to restore or -> <check> [args...]
expect_fail() {
  local name="$1" file="$2"; shift 2
  if "$@" --out "$EV/neg-$name.md" > /dev/null 2>&1; then
    echo "$name: PASSED (the check missed the planted defect)"; rc=1
  else
    echo "$name: FAILED as it should ($(grep -a -m1 -E '^\*\*FAIL' "$EV/neg-$name.md"))"
  fi
  [[ "$file" == - ]] || git checkout -- "$file"
  [[ "$file" == - ]] || git diff --quiet -- "$file" || { echo "RESTORE FAILED: $file"; rc=1; }
}

# plant <file> <python expression on s>
plant() {
  /usr/bin/python3 -I - "$1" "$2" <<'EOF'
import sys
p, expr = sys.argv[1], sys.argv[2]
s = open(p).read()
t = eval(expr)
assert t != s, "the plant did not change " + p
open(p, "w").write(t)
EOF
}

# 1. Byte identity: a bare @freezed on ComicDto loses its JSON under the shim
#    (F-0025), so Bazel's freezed output differs from build_runner's.
plant "$DTO" "s.replace('@Freezed(fromJson: true, toJson: true)\nabstract class ComicDto', '@freezed\nabstract class ComicDto', 1)"
expect_fail byte_identity_bare_freezed "$DTO" tool/checks/T-0041-AC7_matches_build_runner.sh

# 2. Cutoff: the retrofit part reading the whole `_stage` (bloc files
#    included) re-runs on a bloc edit.
plant "$BUILD" "s.replace('''    deps = [\n        \":_stage_dto\",\n        \"@pub_deps//:dio\",''', '''    deps = [\n        \":_stage\",\n        \":_stage_dto\",\n        \"@pub_deps//:dio\",''', 1)"
expect_fail cutoff_retrofit_on_stage "$BUILD" tool/checks/T-0041-AC7_cutoff.sh

# 3. Not committed: a generated-looking file staged in the index.
printf '// planted\n' > "$FAKE"
git add -f "$FAKE"
expect_fail not_committed_staged_g_dart - tool/checks/T-0041-AC7_generated_not_committed.sh
git rm -q --cached "$FAKE"; rm -f "$FAKE"

# 4. gen-l10n parity: the rule told to emit nullable getters, unlike
#    l10n.yaml (what the CLI reads), so the outputs differ.
plant "$BUILD" "s.replace('nullable_getter = False', 'nullable_getter = True', 1)"
expect_fail gen_l10n_nullable_getter "$BUILD" tool/checks/T-0041-AC7_gen_l10n_parity.sh

# Leave the build matching HEAD for whatever runs next.
tool/bazelw $MC_BAZEL_STARTUP build //$PKG:comics_details > /dev/null 2>&1 || true
exit $rc
