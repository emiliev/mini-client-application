#!/bin/bash
# T-0027-AC3: with rules patch 0001 applied by MODULE.bazel (no fork override),
# the ext lock Bazel uses resolves retrofit_generator on analyzer 14.5.0;
# `rules_fork.sh check` and `status` pass; `test //...`, lint and
# mc_arch_check are green.
#   tool/checks/T-0027-AC3_patch_queue_and_ext_lock.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

override=$(grep -c -E '^[^#]*--override_module=ai_rules_dart' .bazelrc.user 2>/dev/null || true)
"$REPO/tool/rules_fork.sh" check > "$TMP/check.log" 2>&1; rc_check=$?
"$REPO/tool/rules_fork.sh" status > "$TMP/status.log" 2>&1; rc_status=$?
"$BAZELW" test --lockfile_mode=error //... > "$TMP/test.log" 2>&1; rc_test=$?
"$BAZELW" build --config=lint //... > "$TMP/lint.log" 2>&1; rc_lint=$?
"$BAZELW" run //tool/mc_arch_check:bin > "$TMP/arch.log" 2>&1; rc_arch=$?

# The ext lock as Bazel patched it into the external repo.
LOCK="$("$BAZELW" info output_base 2>/dev/null)/external/ai_rules_dart+/dart/ext/pubspec.lock"
ver() { awk -v p="  $1:" '$0==p{f=1} f&&/^    version:/{gsub(/"/,"",$2); print $2; exit}' "$LOCK" 2>/dev/null; }
analyzer=$(ver analyzer); build=$(ver build); source_gen=$(ver source_gen)
retrofit_gen=$(ver retrofit_generator); retrofit=$(ver retrofit); dio=$(ver dio)
shim=$("$BAZELW" query @rules_dart//dart/ext/retrofit:shim 2>/dev/null)
tests=$(plain "$TMP/test.log" | grep -a -E '^Executed' | tail -1)

report "# T-0027-AC3: patch queue, ext lock and gates" "" \
  "| Check | Result |" "|---|---|" \
  "| \`--override_module=ai_rules_dart\` lines in .bazelrc.user (must be 0) | $override |" \
  "| \`rules_fork.sh check\` | exit $rc_check: $(grep 'ai_rules_dart' "$TMP/check.log" | head -1) |" \
  "| \`rules_fork.sh status\` | exit $rc_status: $(grep -A1 '^ai_rules_dart' "$TMP/status.log" | tr '\n' ' ') |" \
  "| patched ext lock: analyzer / build / source_gen | $analyzer / $build / $source_gen |" \
  "| patched ext lock: retrofit_generator / retrofit / dio | $retrofit_gen / $retrofit / $dio |" \
  "| \`@rules_dart//dart/ext/retrofit:shim\` exists | ${shim:-no} |" \
  "| \`test --lockfile_mode=error //...\` | exit $rc_test: $tests |" \
  "| \`build --config=lint //...\` | exit $rc_lint |" \
  "| \`run //tool/mc_arch_check:bin\` | exit $rc_arch: $(tail -1 "$TMP/arch.log") |"
ok=1
[[ "$override" -eq 0 && $rc_check -eq 0 && $rc_status -eq 0 ]] || ok=0
[[ "$analyzer" == "14.5.0" && "$retrofit_gen" == "10.3.3" && "$retrofit" == "4.10.0" && -n "$shim" ]] || ok=0
[[ $rc_test -eq 0 && $rc_lint -eq 0 && $rc_arch -eq 0 ]] || ok=0
finish T-0027-AC3 $([[ $ok -eq 1 ]] && echo 0 || echo 1)
