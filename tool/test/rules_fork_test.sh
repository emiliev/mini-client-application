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

# checkout (shared by AC1 and AC3)
out="$("$REPO/tool/rules_fork.sh" checkout ai_rules_dart 2>&1)" || { echo "$out"; bad checkout_setup; exit 1; }

# ---- AC3 (part 2): checkout writes an absolute path into a git-ignored .bazelrc.user
rc="$WS/.bazelrc.user"
want="common --override_module=ai_rules_dart=$(cd "$FORK" && pwd -P)"
if grep -qxF "$want" "$rc" && [[ "$(cd "$FORK" && pwd -P)" == /* ]]; then
  ok T-0024-AC3_checkout_writes_absolute_override
else bad T-0024-AC3_checkout_writes_absolute_override "$(cat "$rc" 2>/dev/null)"; fi
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
cp "$rc" "$TMP/rc.bak"
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
sed -i '' 's#a/data.txt#a/missing.txt#; s#b/data.txt#b/missing.txt#' "$WS/third_party/rules_patches/ai_rules_dart/0001-Change-line-two.patch"
out="$(bz build //:out)"; r=$?
if [[ $r -ne 0 && "$out" == *"0001-Change-line-two.patch"* ]]; then ok T-0024-AC2_unappliable_patch_fails_naming_it
else bad T-0024-AC2_unappliable_patch_fails_naming_it "r=$r"; echo "$out" | tail -5; fi

# AC2 companion: checkout (git am) rejects a queued patch that does not apply, naming it.
rm -rf "$FORK"
out="$("$REPO/tool/rules_fork.sh" checkout ai_rules_dart 2>&1)"; r=$?
if [[ $r -ne 0 && "$out" == *"0001-Change-line-two.patch"* ]]; then ok T-0024-AC2_checkout_rejects_unappliable_queued_patch
else bad T-0024-AC2_checkout_rejects_unappliable_queued_patch "r=$r $out"; fi

# ---- AC3: a binary hunk makes export refuse, naming the file; the queue is left alone
rm -rf "$FORK" "$WS/third_party/rules_patches/ai_rules_dart"/[0-9]*.patch
"$REPO/tool/rules_fork.sh" checkout ai_rules_dart >/dev/null 2>&1
cd "$FORK"
printf '\000\001\002\377binary' > blob.bin && git_ add blob.bin && git_ commit -qm "Add blob"
cd "$REPO"
out="$("$REPO/tool/rules_fork.sh" export ai_rules_dart 2>&1)"; r=$?
left="$(ls "$WS/third_party/rules_patches/ai_rules_dart"/*.patch 2>/dev/null | wc -l | tr -d ' ')"
if [[ $r -ne 0 && "$out" == *"blob.bin"* && "$left" == 0 ]]; then ok T-0024-AC3_export_refuses_binary_hunk_naming_file
else bad T-0024-AC3_export_refuses_binary_hunk_naming_file "r=$r left=$left $out"; fi

# ---- AC4: the real repo's queue state is consistent (status agrees; zero patches listed or all present)
cd "$REPO"
unset MC_REPO_ROOT MC_FORK_DIR
status="$("$REPO/tool/rules_fork.sh" status 2>&1)"
okq=1
for r in ai_rules_dart ai_rules_flutter; do
  q="$(ls "$REPO/third_party/rules_patches/$r"/[0-9][0-9][0-9][0-9]-*.patch 2>/dev/null | wc -l | tr -d ' ')"
  l="$(grep -v '^[[:space:]]*#' "$REPO/MODULE.bazel" | grep -c "\"//third_party/rules_patches/$r:")"
  [[ "$q" == "$l" ]] || okq=0
done
if [[ $okq == 1 && "$status" == *"ai_rules_dart: pin"* ]]; then ok T-0024-AC4_committed_queue_matches_module_bazel
else bad T-0024-AC4_committed_queue_matches_module_bazel "$status"; fi

echo "rules_fork_test: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
