#!/bin/bash
# tool/test/rules_fork_test.sh: tests for tool/rules_fork.sh, one per acceptance criterion of T-0024.
# Fully local: a fake upstream module in a temp git repo stands in for ai_rules_dart (no network,
# no shared state). The AC1/AC2 builds run real Bazel in a throwaway workspace and output base.
#   tool/test/rules_fork_test.sh
set -uo pipefail
REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
TMP="$(mktemp -d)"
BAZEL="$REPO/tool/bazelw"
WS="$TMP/ws"
OB="$TMP/ob"
cleanup() {
  [[ -d "$WS" ]] && (cd "$WS" && "$BAZEL" --output_base="$OB" shutdown >/dev/null 2>&1)
  rm -rf "$TMP"
}
trap cleanup EXIT

pass=0; fail=0
ok()  { echo "PASS $1"; pass=$((pass+1)); }
bad() { echo "FAIL $1${2:+: $2}"; fail=$((fail+1)); }
git_() { git -c user.name=t -c user.email=t@localhost "$@"; }

# Fake upstream: module ai_rules_dart with a text file and an executable-free BUILD.
UP="$TMP/upstream"
mkdir -p "$UP" && cd "$UP" && git init -q -b main
printf 'module(name = "ai_rules_dart", version = "0.0.1")\n' > MODULE.bazel
printf 'exports_files(["data.txt"])\n' > BUILD.bazel
printf 'line one\nline two\nline three\n' > data.txt
printf 'readme\n' > README.md
git_ add -A && git_ commit -qm "upstream" && PIN="$(git rev-parse HEAD)"

# Consumer workspace that mirrors the real wiring (MODULE.bazel + third_party/rules_patches).
mkdir -p "$WS/third_party/rules_patches/ai_rules_dart" "$WS/third_party/rules_patches/ai_rules_flutter" "$WS/tool"
cp "$REPO/.bazelversion" "$WS/.bazelversion"
cp "$REPO/third_party/rules_patches/ai_rules_dart/BUILD.bazel" "$WS/third_party/rules_patches/ai_rules_dart/"
echo "try-import %workspace%/.bazelrc.user" > "$WS/.bazelrc"
cat > "$WS/BUILD.bazel" <<'EOF'
genrule(
    name = "out",
    srcs = ["@ai_rules_dart//:data.txt"],
    outs = ["out.txt"],
    cmd = "cp $< $@",
)
EOF
write_module() {  # patch labels...
  {
    echo 'module(name = "consumer")'
    echo 'bazel_dep(name = "ai_rules_dart", version = "0.0.1")'
    echo 'git_override('
    echo '    module_name = "ai_rules_dart",'
    echo "    commit = \"$PIN\","
    echo "    remote = \"file://$UP\","
    echo '    patch_strip = 1,'
    echo '    patches = ['
    local p; for p in "$@"; do echo "        \"//third_party/rules_patches/ai_rules_dart:$p\","; done
    echo '    ],'
    echo ')'
  } > "$WS/MODULE.bazel"
}
write_module
export MC_REPO_ROOT="$WS" MC_FORK_DIR="$TMP/forks"
FORK="$TMP/forks/ai_rules_dart"
bz() { (cd "$WS" && "$BAZEL" --output_base="$OB" "$@" --lockfile_mode=off 2>&1); }

# checkout (shared by AC1 and AC3). The user's own .bazelrc.user lines, and an override for the
# other repo inside a stale managed block, must survive it.
printf '# my own\ncommon --jobs=3\n# >>> rules_fork.sh (generated; git-ignored)\ncommon --override_module=ai_rules_flutter=/x/y\n# <<< rules_fork.sh\nbuild --keep_going\n' > "$WS/.bazelrc.user"
out="$("$REPO/tool/rules_fork.sh" checkout ai_rules_dart 2>&1)" || { echo "$out"; bad checkout_setup; exit 1; }

# ---- AC3 (part 2): checkout writes an absolute path into a git-ignored .bazelrc.user
rc="$WS/.bazelrc.user"
want="common --override_module=ai_rules_dart=$(cd "$FORK" && pwd -P)"
if grep -qxF "$want" "$rc" && [[ "$(cd "$FORK" && pwd -P)" == /* ]]; then
  ok T-0024-AC3_checkout_writes_absolute_override
else bad T-0024-AC3_checkout_writes_absolute_override "$(cat "$rc" 2>/dev/null)"; fi
if grep -qxF '# my own' "$rc" && grep -qxF 'common --jobs=3' "$rc" && grep -qxF 'build --keep_going' "$rc" \
   && grep -qxF 'common --override_module=ai_rules_flutter=/x/y' "$rc" && [[ "$(grep -c '>>> rules_fork' "$rc")" == 1 ]]; then
  ok T-0024-AC3_checkout_preserves_user_bazelrc_lines
else bad T-0024-AC3_checkout_preserves_user_bazelrc_lines "$(cat "$rc")"; fi
if (cd "$REPO" && git check-ignore -q .bazelrc.user); then ok T-0024-AC3_bazelrc_user_is_gitignored
else bad T-0024-AC3_bazelrc_user_is_gitignored; fi

# ---- AC1: N commits in the fork -> N patches; patches build the same as --override_module
cd "$FORK"
printf 'line one\nline TWO\nline three\n' > data.txt && git_ commit -qam "Change line two"
printf 'readme\nmore\n' > README.md && git_ commit -qam "Extend readme"
cd "$REPO"
out="$("$REPO/tool/rules_fork.sh" export ai_rules_dart 2>&1)"; rc_=$?
n="$(ls "$WS/third_party/rules_patches/ai_rules_dart"/[0-9][0-9][0-9][0-9]-*.patch 2>/dev/null | wc -l | tr -d ' ')"
if [[ $rc_ -eq 0 && "$n" == 2 && -f "$WS/third_party/rules_patches/ai_rules_dart/0001-Change-line-two.patch" ]]; then
  ok T-0024-AC1_export_writes_one_patch_per_commit
else bad T-0024-AC1_export_writes_one_patch_per_commit "rc=$rc_ n=$n $out"; fi

# Build with the override (the .bazelrc.user from checkout), then with the patch queue only.
grep -v ai_rules_flutter "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"  # the fake workspace has no such module
out1="$(bz build //:out)"; r1=$?
bytes_override="$(cat "$WS/bazel-bin/out.txt" 2>/dev/null)"
rm -f "$rc"
write_module 0001-Change-line-two.patch 0002-Extend-readme.patch
out2="$(bz build //:out)"; r2=$?
bytes_patches="$(cat "$WS/bazel-bin/out.txt" 2>/dev/null)"
readme_p="$(cat "$OB"/external/ai_rules_dart+/README.md 2>/dev/null)"
if [[ $r1 -eq 0 && $r2 -eq 0 && "$bytes_override" == *"line TWO"* && "$bytes_override" == "$bytes_patches" \
      && "$readme_p" == $'readme\nmore' ]]; then
  ok T-0024-AC1_git_override_patches_build_same_as_override_module
else bad T-0024-AC1_git_override_patches_build_same_as_override_module "r1=$r1 r2=$r2 override='$bytes_override' patches='$bytes_patches'"; echo "$out1" | tail -5; echo "$out2" | tail -5; fi

# ---- AC2: a patch that does not apply fails the build, naming the patch
P1="$WS/third_party/rules_patches/ai_rules_dart/0001-Change-line-two.patch"
sed 's#a/data.txt#a/missing.txt#; s#b/data.txt#b/missing.txt#' "$P1" > "$P1.tmp" && mv "$P1.tmp" "$P1"
out="$(bz build //:out)"; r=$?
if [[ $r -ne 0 && "$out" == *"0001-Change-line-two.patch"* ]]; then ok T-0024-AC2_unappliable_patch_fails_naming_it
else bad T-0024-AC2_unappliable_patch_fails_naming_it "r=$r"; echo "$out" | tail -5; fi

# AC2 companion: checkout (git am) rejects a queued patch that does not apply, naming it.
rm -rf "$FORK"
out="$("$REPO/tool/rules_fork.sh" checkout ai_rules_dart 2>&1)"; r=$?
if [[ $r -ne 0 && "$out" == *"0001-Change-line-two.patch"* ]]; then ok T-0024-AC2_checkout_rejects_unappliable_queued_patch
else bad T-0024-AC2_checkout_rejects_unappliable_queued_patch "r=$r $out"; fi

# ---- helpers for the export guards: a fresh fork per scenario
QDIR="$WS/third_party/rules_patches/ai_rules_dart"
reset_fork() {
  rm -rf "$FORK" "$QDIR"/[0-9]*.patch
  "$REPO/tool/rules_fork.sh" checkout ai_rules_dart >/dev/null 2>&1
}
seed_queue() {  # one real exported patch, so "survives a refused export" is observable
  reset_fork
  (cd "$FORK" && printf 'seed\n' > seed.txt && git_ add seed.txt && git_ commit -qm "Seed")
  "$REPO/tool/rules_fork.sh" export ai_rules_dart >/dev/null 2>&1
  rm -rf "$FORK"; "$REPO/tool/rules_fork.sh" checkout ai_rules_dart >/dev/null 2>&1
}
queue_names() { (cd "$QDIR" && ls [0-9]*.patch 2>/dev/null | tr '\n' ' '); }

# ---- AC3: a binary hunk makes export refuse, naming the file; the pre-seeded queue survives
seed_queue
before="$(queue_names)"
(cd "$FORK" && printf '\000\001\002\377binary' > blob.bin && git_ add blob.bin && git_ commit -qm "Add blob")
out="$("$REPO/tool/rules_fork.sh" export ai_rules_dart 2>&1)"; r=$?
if [[ $r -ne 0 && "$out" == *"blob.bin"* && -n "$before" && "$(queue_names)" == "$before" ]]; then ok T-0024-AC3_export_refuses_binary_hunk_naming_file
else bad T-0024-AC3_export_refuses_binary_hunk_naming_file "r=$r before='$before' after='$(queue_names)' $out"; fi

# AC3: a binary added in one commit and removed in the next is still refused (per-commit check)
(cd "$FORK" && git_ rm -q blob.bin && git_ commit -qm "Remove blob")
out="$("$REPO/tool/rules_fork.sh" export ai_rules_dart 2>&1)"; r=$?
if [[ $r -ne 0 && "$out" == *"blob.bin"* && "$(queue_names)" == "$before" ]]; then ok T-0024-AC3_export_refuses_binary_added_then_removed
else bad T-0024-AC3_export_refuses_binary_added_then_removed "r=$r $out"; fi

# ---- AC1: merge commits in the fork are refused, queue untouched
seed_queue
before="$(queue_names)"
(cd "$FORK" && git_ checkout -q -b side && printf 's\n' > side.txt && git_ add side.txt && git_ commit -qm "Side" \
  && git_ checkout -q fork && printf 'm\n' > main.txt && git_ add main.txt && git_ commit -qm "Main" \
  && git_ merge -q --no-ff side -m "Merge side")
out="$("$REPO/tool/rules_fork.sh" export ai_rules_dart 2>&1)"; r=$?
if [[ $r -ne 0 && "$out" == *"merge"* && "$(queue_names)" == "$before" ]]; then ok T-0024-AC1_export_refuses_merge_commits
else bad T-0024-AC1_export_refuses_merge_commits "r=$r $out"; fi

# ---- AC1/AC2: export after a failed checkout (open git am session) is refused; queue survives
seed_queue
before="$(queue_names)"
rm -rf "$FORK"
mv "$QDIR/0001-Seed.patch" "$TMP/seed.patch"
# Two patches where the second (a copy of the first) cannot apply: checkout dies mid-am.
cp "$TMP/seed.patch" "$QDIR/0001-Seed.patch"
cp "$TMP/seed.patch" "$QDIR/0002-Other.patch"
"$REPO/tool/rules_fork.sh" checkout ai_rules_dart >/dev/null 2>&1
before="$(queue_names)"
out="$("$REPO/tool/rules_fork.sh" export ai_rules_dart 2>&1)"; r=$?
if [[ $r -ne 0 && ( "$out" == *"git am"* || "$out" == *"queue holds"* ) && "$(queue_names)" == "$before" ]]; then ok T-0024-AC2_export_refuses_after_failed_checkout
else bad T-0024-AC2_export_refuses_after_failed_checkout "r=$r $out"; fi

# AC1: a fork HEAD off branch 'fork' is refused
seed_queue
before="$(queue_names)"
(cd "$FORK" && git_ checkout -q --detach)
out="$("$REPO/tool/rules_fork.sh" export ai_rules_dart 2>&1)"; r=$?
if [[ $r -ne 0 && "$out" == *"not on branch"* && "$(queue_names)" == "$before" ]]; then ok T-0024-AC1_export_refuses_detached_head
else bad T-0024-AC1_export_refuses_detached_head "r=$r $out"; fi

# AC1: fewer fork commits than queued patches is refused without --force, allowed with it
seed_queue
(cd "$FORK" && git_ reset -q --hard HEAD~1)
out="$("$REPO/tool/rules_fork.sh" export ai_rules_dart 2>&1)"; r=$?
kept="$(queue_names)"
out2="$("$REPO/tool/rules_fork.sh" export --force ai_rules_dart 2>&1)"; r2=$?
if [[ $r -ne 0 && "$out" == *"drop"* && -n "$kept" && $r2 -eq 0 && -z "$(queue_names)" ]]; then ok T-0024-AC1_export_refuses_dropping_patches_without_force
else bad T-0024-AC1_export_refuses_dropping_patches_without_force "r=$r r2=$r2 kept='$kept' $out"; fi

# ---- AC4 / status: names and order are compared; commented override lines are not ACTIVE
reset_fork
printf '# common --override_module=ai_rules_dart=/nowhere\n' > "$WS/.bazelrc.user"
st="$("$REPO/tool/rules_fork.sh" status 2>&1)"
if [[ "$st" == *"override: none"* ]]; then ok T-0024-AC4_status_ignores_commented_override
else bad T-0024-AC4_status_ignores_commented_override "$st"; fi
write_module 0002-b.patch 0001-a.patch   # listed, but not in the queue (and out of order)
printf 'x' > "$QDIR/0001-a.patch"; printf 'x' > "$QDIR/0002-b.patch"
st="$("$REPO/tool/rules_fork.sh" status 2>&1)"; r=$?
if [[ $r -ne 0 && "$st" == *"MISMATCH"* ]]; then ok T-0024-AC4_status_detects_order_mismatch
else bad T-0024-AC4_status_detects_order_mismatch "r=$r $st"; fi
write_module 0001-a.patch 0002-b.patch
st="$("$REPO/tool/rules_fork.sh" status 2>&1)"; r=$?
if [[ $r -eq 0 && "$st" == *"match the queue"* ]]; then ok T-0024-AC4_status_accepts_matching_order
else bad T-0024-AC4_status_accepts_matching_order "r=$r $st"; fi

# ---- AC4: the real repo's committed queue matches MODULE.bazel (names and order)
cd "$REPO"
unset MC_REPO_ROOT MC_FORK_DIR
status="$("$REPO/tool/rules_fork.sh" status 2>&1)"; r=$?
if [[ $r -eq 0 && "$status" == *"ai_rules_dart: pin"* ]]; then ok T-0024-AC4_committed_queue_matches_module_bazel
else bad T-0024-AC4_committed_queue_matches_module_bazel "$status"; fi

echo "rules_fork_test: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
