#!/bin/bash
# Argument-handling tests for tool/bazelw (T-0014 code review, finding 4).
# Uses a stub bazelisk that prints its argv, so no Bazel runs.
#   tool/test/bazelw_test.sh
set -uo pipefail
REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/bazelisk" <<'EOF'
#!/bin/bash
printf '%s\n' "$@"
EOF
chmod +x "$TMP/bazelisk"

pass=0; fail=0
check() {  # name, expected argv (one per line), args...
  local name="$1" want="$2"; shift 2
  local got rc
  got="$(MC_BAZELISK="$TMP/bazelisk" "$REPO/tool/bazelw" "$@" 2>/dev/null)"; rc=$?
  if [[ $rc -eq 0 && "$got" == "$want" ]]; then echo "PASS $name"; pass=$((pass+1))
  else echo "FAIL $name"; echo "  want: $(echo "$want" | tr '\n' ' ')"; echo "  got:  $(echo "$got" | tr '\n' ' ') (exit $rc)"; fail=$((fail+1)); fi
}
expect_exit() {  # name, code, args...
  local name="$1" code="$2"; shift 2
  MC_BAZELISK="$TMP/bazelisk" "$REPO/tool/bazelw" "$@" >/dev/null 2>&1; local rc=$?
  if [[ $rc -eq $code ]]; then echo "PASS $name"; pass=$((pass+1)); else echo "FAIL $name (exit $rc, want $code)"; fail=$((fail+1)); fi
}

check plain_passthrough $'build\n//spike/...' build //spike/...
check budget16_after_command_inserted $'--host_jvm_args=-Xmx3g\nbuild\n--config=budget16\n//...' --budget16 build //...
check budget16_with_startup_option_first \
  $'--output_user_root=/x\n--host_jvm_args=-Xmx3g\ntest\n--config=budget16\n//a:b' \
  --output_user_root=/x --budget16 test //a:b
check budget16_after_command_not_matched $'run\n//a:b\n--budget16' run //a:b --budget16
check budget16_after_dashdash_not_matched $'--\nrun\n--budget16' -- run --budget16
check startup_options_kept_in_order $'--nohome_rc\n--batch\nversion' --nohome_rc --batch version
expect_exit budget16_without_command_fails 2 --budget16
MC_BAZELISK="$TMP/missing" "$REPO/tool/bazelw" version >/dev/null 2>&1
if [[ $? -eq 2 ]]; then echo "PASS missing_bazelisk_exit_2"; pass=$((pass+1)); else echo "FAIL missing_bazelisk_exit_2"; fail=$((fail+1)); fi

echo "bazelw_test: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
