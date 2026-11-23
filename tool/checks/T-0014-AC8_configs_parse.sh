#!/bin/bash
# T-0014-AC8: every .bazelrc config parses on Bazel 9.3.0 with no unknown option
# or config (`--nobuild`, so nothing executes).
#   tool/checks/T-0014-AC8_configs_parse.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
BAD='unrecognized option|unknown option|is not defined|added more than once|expanded more than once'
status=0
report "# T-0014-AC8: configs parse" "" "| Command | Exit | Bad lines | Verdict |" "|---|---|---|---|"
run() {  # run <expected: ok|notests|undefined> args...
  local expect="$1"; shift
  local log; log="$(mktemp)"
  "$BAZELW" "$@" > "$log" 2>&1; local rc=$?
  local bad; bad=$(plain "$log" | grep -a -c -i -E "$BAD" || true)
  local ok=0
  case "$expect" in
    ok) [[ $rc -eq 0 && $bad -eq 0 ]] && ok=1 ;;
    # `test --nobuild` always ends "Unable to run tests" (exit 1); the analysis must still complete.
    testnobuild) plain "$log" | grep -a -q 'Build completed successfully' && [[ $bad -eq 0 ]] && ok=1 ;;
    # No app-tagged test exists yet: the tag filter excluded everything, which proves the config parsed.
    notests) plain "$log" | grep -a -q 'excluded by filters' && [[ $bad -eq 0 ]] && ok=1 ;;
    undefined) [[ $rc -ne 0 ]] && plain "$log" | grep -a -q -i 'not defined' && ok=1 ;;
  esac
  [[ $ok -eq 1 ]] || status=1
  report "| \`tool/bazelw $*\` | $rc | $bad | $([[ $ok -eq 1 ]] && echo ok || echo FAIL) |"
  rm -f "$log"
}
run ok build --nobuild --config=lint //spike/...
run testnobuild test --nobuild --config=lint //spike/...
run ok build --nobuild --config=ci --config=cold //spike/...
run ok build --nobuild --config=budget16 //spike/...
run ok --budget16 build --nobuild //spike/...
run ok build --nobuild --config=budget16_8c //spike/...
run ok build --nobuild --config=profile //spike/...
run ok build --nobuild --config=remote-cache //spike/...
run ok build --nobuild --config=sim //spike/hello:hello_ios
run ok build --nobuild --config=device-profile //spike/...
run notests test --nobuild --config=app //spike/...
run undefined build --nobuild --config=no_such_config //spike/...
# Not just parsing: lint really runs analyze + format over the committed tree,
# so a stale log can't stand in for it.
run ok build --config=lint //spike/...
fmt_log="$(mktemp)"
fvm dart format --output=none --set-exit-if-changed spike > "$fmt_log" 2>&1; rc_fmt=$?
report "| \`fvm dart format --output=none --set-exit-if-changed spike\` | $rc_fmt | $(grep -c '^Changed' "$fmt_log") | $([[ $rc_fmt -eq 0 ]] && echo ok || echo FAIL) |"
[[ $rc_fmt -eq 0 ]] || status=1
rm -f "$fmt_log"
report "" "The \`no_such_config\` row is a negative control: an undefined config must fail." \
  "\`test --nobuild\` always exits 1 (\"Unable to run tests\"), so its row passes when analysis completed with no bad lines; \`test --config=app\` has no \`app\`-tagged test yet; \"excluded by filters\" shows its tag filter applied."
finish T-0014-AC8 $status
