#!/bin/bash
# T-0053-AC5: the gates for mc_analytics, in one check that fails when any of
# them fails.
#   1. closure of //utility/mc_analytics:mc_analytics has no network client and
#      no third-party SDK (P-004: dio, http, firebase, sentry, ...).
#      Positive control: the closure of //utility/mc_api_client has dio, so a
#      query that cannot see it fails the check. Negative control: a throwaway,
#      untracked package that depends on mc_analytics AND on mc_api_client shows
#      dio in its closure (and is removed again, tree clean).
#   2. globs over lib/** use MC_GENERATED_DART. Negative control: the same
#      check run on a copy of the BUILD file without the exclusion fails.
#   3. workspace registration in the root pubspec.yaml
#   4. test //... (packages T-0053 touches uncached), `test --lockfile_mode=error`,
#      the bundled config of each env (dev, e2e, perf) says what AC1 needs
#   5. build --config=lint //..., mc_arch_check, rules_fork.sh check, dart format,
#      l10n_check
#   6. coverage of every touched package with hand-written lib/ code >=
#      MC_COVERAGE_MIN (default 90, ADR-0010)
#   The e2e on a simulator is run through tool/e2e_ios.sh (see the task file).
#   tool/checks/T-0053-AC5_gates.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
MIN="${MC_COVERAGE_MIN:-90}"
work="$(mktemp -d)"
neg_dir=utility/zz_negctl_T0053_net
cleanup() { rm -rf "$neg_dir" "$work"; }
trap cleanup EXIT
rows=()
fails=()
ok=1
logname() { printf '%s/%s.log' "$work" "$(tr -c 'a-zA-Z0-9' _ <<< "$1")"; }
gate() {  # gate <name> <command...>
  local name="$1"; shift
  local log; log="$(logname "$name")"
  if "$@" > "$log" 2>&1; then
    rows+=("| $name | PASS |")
  else
    rows+=("| $name | **FAIL** |"); ok=0
    fails+=("" "### $name failed" "" '```' "$(plain "$log" | grep -a -v '^\[' | tail -25)" '```')
  fi
}
closure() { bzw cquery "deps($1)" 2>/dev/null | sed 's/ (.*//'; }

# 1. no network client, no third-party SDK
NET='pub_deps__(dio|http|http_parser|firebase[a-z_]*|sentry[a-z_]*|amplitude[a-z_]*|mixpanel[a-z_]*|segment[a-z_]*)//|pub_deps//:(dio|http|firebase[a-z_]*|sentry[a-z_]*)$'
deps="$(closure //utility/mc_analytics:mc_analytics)"
n="$(grep -c . <<< "$deps")"
hits="$(grep -E "$NET" <<< "$deps" | sort -u | head -5)"
control="$(closure //utility/mc_api_client:mc_api_client | grep -E "$NET" | sort -u | head -3)"
[[ ! -e "$neg_dir" ]] || { echo "refusing: $neg_dir exists" >&2; exit 2; }
mkdir -p "$neg_dir/lib"
printf 'library;\n' > "$neg_dir/lib/x.dart"
cat > "$neg_dir/BUILD.bazel" <<'EOF'
load("@rules_dart//dart:defs.bzl", "dart_library")

dart_library(
    name = "zz_negctl_net",
    package_name = "zz_negctl_net",
    srcs = ["lib/x.dart"],
    language_version = "3.13",
    visibility = ["//visibility:public"],
    deps = [
        "//utility/mc_analytics",
        "//utility/mc_api_client",
    ],
)
EOF
neg_hits="$(closure //$neg_dir:zz_negctl_net | grep -E "$NET" | sort -u | head -3)"
rm -rf "$neg_dir"
restored=1; [[ -z "$(git status --porcelain -- "$neg_dir")" && ! -e "$neg_dir" ]] || restored=0
report "# T-0053-AC5: gates" "" \
  "## closure of mc_analytics ($n targets)" '```' "network or SDK markers: ${hits:-none}" '```' \
  "## positive control: mc_api_client" '```' "markers: ${control:-none}" '```' \
  "## negative control: a throwaway target depending on mc_analytics and mc_api_client" '```' \
  "markers: ${neg_hits:-NOT DETECTED}" "throwaway package removed, tree clean: $([[ $restored == 1 ]] && echo yes || echo NO)" '```'
if [[ "$restored" == 1 && "$n" -ge 20 && -z "$hits" && -n "$control" && -n "$neg_hits" ]]; then
  rows+=("| no network client or SDK in the closure | PASS |")
else
  rows+=("| no network client or SDK in the closure | **FAIL** |"); ok=0
fi

# 2. globs use MC_GENERATED_DART
globs_ok() {  # globs_ok <BUILD file>: every glob over lib/** excludes it
  python3 -I - "$1" <<'EOF'
import re, sys
s = open(sys.argv[1]).read()
globs = re.findall(r'glob\(\s*\[[^\]]*lib/\*\*[^\]]*\](?:[^()]|\([^()]*\))*?\)', s)
if not globs:
    sys.exit(2)
sys.exit(0 if all('MC_GENERATED_DART' in g for g in globs) else 1)
EOF
}
globs_ok utility/mc_analytics/BUILD.bazel; pos=$?
sed 's/, exclude = MC_GENERATED_DART//' utility/mc_analytics/BUILD.bazel > "$work/BUILD.noexclude"
globs_ok "$work/BUILD.noexclude"; neg=$?
report "## globs over lib/** use MC_GENERATED_DART" '```' "real BUILD: exit $pos (0 = every glob excludes it)" "control without the exclusion: exit $neg (must be 1)" '```'
if [[ "$pos" == 0 && "$neg" == 1 ]]; then rows+=("| globs use MC_GENERATED_DART | PASS |"); else rows+=("| globs use MC_GENERATED_DART | **FAIL** |"); ok=0; fi

# 3. registration
if grep -qx '  - utility/mc_analytics' pubspec.yaml; then rows+=("| workspace registration | PASS |"); else rows+=("| workspace registration | **FAIL** |"); ok=0; fi

# 4. tests
uncached=(//utility/mc_analytics/... //utility/mc_config/... //utility/mc_test_steps/... //utility/mc_test_utils/... //app/...)
tests() { bzw test --nocache_test_results "${uncached[@]}" && bzw test //...; }
gate "test //... (touched packages uncached)" tests
gate "test --lockfile_mode=error //..." bzw test --lockfile_mode=error //...
# The shipped configs: dev and e2e grant consent by default, perf does not.
bundled_configs() {
  local env
  for env in dev e2e perf; do
    bzw test --nocache_test_results --//tool/bazel/config:env="$env" //utility/mc_config:bundled_config_test || return 1
  done
}
gate "bundled configs (dev, e2e, perf)" bundled_configs

# 5. repo gates
gate "build --config=lint //..." bzw build --config=lint //...
gate "mc_arch_check" bzw run //tool/mc_arch_check:bin
gate "rules_fork.sh check" "$REPO/tool/rules_fork.sh" check
gate "dart format" fvm dart format --output=none --set-exit-if-changed \
  app feature spike utility tool/l10n_check tool/mc_arch_check
gate "l10n_check" bzw run //tool/l10n_check:bin -- "$REPO"

# 6. coverage
PKGS=(utility/mc_analytics utility/mc_config app/wiring/app_core app/mini_client)
coverage() {
  local pkg rc=0
  : > "$work/coverage.txt"
  bzw coverage $(printf '//%s/... ' "${PKGS[@]}") || return 1
  for pkg in "${PKGS[@]}"; do
    echo "== $pkg" >> "$work/coverage.txt"
    /usr/bin/python3 -I "$REPO/tool/checks/merge_lcov.py" \
      "$(bzw info output_path 2>/dev/null)" "$pkg" "$MIN" >> "$work/coverage.txt" || { echo "UNDER $MIN: $pkg" >> "$work/coverage.txt"; rc=1; }
  done
  cat "$work/coverage.txt"
  return $rc
}
gate "coverage >= $MIN % (touched packages)" coverage
total=$(grep -a -E '^(==|TOTAL|UNDER)' "$work/coverage.txt" 2>/dev/null | paste -sd" " - || echo 'not measured')
tests_line=$(plain "$(logname "test //... (touched packages uncached)")" 2>/dev/null | grep -a 'Executed' | head -1)

report "" "| Gate | Result |" "|---|---|" "${rows[@]}" "" \
  "- tests: ${tests_line:-?}" "- coverage: $total (threshold $MIN %)" \
  ${fails[@]+"${fails[@]}"}
finish T-0053-AC5-gates $([[ $ok -eq 1 ]] && echo 0 || echo 1)
