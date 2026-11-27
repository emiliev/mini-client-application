#!/bin/bash
# T-0061-AC5: mc_fixtures_identity is pure Dart, registered, covered at >= 90 %,
# and no production target reaches it; plus the repo gates.
#   1. closure of //utility/mc_fixtures_identity:mc_fixtures_identity has no Flutter
#      markers (as T-0030-AC7). Positive control: the closure of
#      //utility/mc_fixtures_media has them, so a query that cannot see
#      Flutter fails the check. Negative control: a throwaway target that
#      depends on the identity package and on the media package shows them.
#   2. workspace registration in the root pubspec.yaml
#   3. fixtures check: no production feature or utility target reaches it
#      (T-0031-AC6 scan). Positive control: its own test target does.
#      Negative control: a throwaway production target that depends on it is
#      detected. Neither control edits a tracked file.
#   4. gates: test //..., lint, mc_arch_check, rules_fork.sh check, format,
#      l10n_check
#   5. coverage of the package's lib/ >= MC_COVERAGE_MIN (default 90)
#   tool/checks/T-0061-AC5_gates.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
MIN="${MC_COVERAGE_MIN:-90}"
FLUTTER='sky_engine|flutter_ios_engine|pub_deps__flutter[_a-z]*//|pub_deps__flutter_test|@@rules_flutter|//flutter:'
work="$(mktemp -d)"
# The negative controls never edit a tracked file: each builds a throwaway,
# untracked Bazel package (removed by the trap, and `git status` must be clean
# of it afterwards) that depends on the identity package.
neg_flutter=utility/zz_negctl_T0061_flutter
neg_prod=feature/zz_negctl_T0061/zz_negctl_T0061_prod
# MADE lists only what this script created (the cleanup removes nothing else);
# a refusal sets neg_refused, which fails the gate.
MADE=()
neg_refused=0
make_neg() {  # make_neg <root> <dir> <package> <dep>...
  local root="$1" dir="$2" pkg="$3"; shift 3
  if [[ -e "$root" ]]; then
    echo "refusing: $root exists" >&2; neg_refused=1; return 1
  fi
  MADE+=("$root")
  mkdir -p "$dir/lib"
  printf 'library;\n' > "$dir/lib/x.dart"
  {
    printf 'load("@rules_dart//dart:defs.bzl", "dart_library")\n\n'
    printf 'dart_library(\n    name = "%s",\n    package_name = "%s",\n' "$pkg" "$pkg"
    printf '    srcs = ["lib/x.dart"],\n    language_version = "3.13",\n    visibility = ["//visibility:public"],\n    deps = [\n' 
    for d in "$@"; do printf '        "%s",\n' "$d"; done
    printf '    ],\n)\n'
  } > "$dir/BUILD.bazel"
}
cleanup() {
  local d
  for d in ${MADE[@]+"${MADE[@]}"}; do rm -rf "$d"; done
  rm -rf "$work"
}
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

# 1. purity
deps="$(closure //utility/mc_fixtures_identity:mc_fixtures_identity)"
n="$(grep -c . <<< "$deps")"
hits="$(grep -E "$FLUTTER" <<< "$deps" | sort -u | head -5)"
# The positive control is the Flutter-bound media package: a query that
# cannot see Flutter would fail the check.
control="$(closure //utility/mc_fixtures_media:mc_fixtures_media | grep -E "$FLUTTER" | sort -u | head -3)"
report "# T-0061-AC5: pure Dart, registered, covered" "" \
  "## closure of mc_fixtures_identity ($n targets)" '```' "Flutter markers: ${hits:-none}" '```' \
  "## positive control: mc_fixtures_media" '```' "Flutter markers: ${control:-none}" '```'
# Negative control: a target that depends on the identity package AND on the
# Flutter-bound media package must show Flutter markers in its closure.
make_neg "$neg_flutter" "$neg_flutter" zz_negctl_flutter //utility/mc_fixtures_identity //utility/mc_fixtures_media || true
neg_hits="$(closure //$neg_flutter:zz_negctl_flutter | grep -E "$FLUTTER" | sort -u | head -3)"
[[ " ${MADE[*]-} " == *" $neg_flutter "* ]] && rm -rf "$neg_flutter"
restored=1; [[ -z "$(git status --porcelain -- "$neg_flutter")" && ! -e "$neg_flutter" ]] || restored=0
report "## negative control: a throwaway target depending on the identity package and on mc_fixtures_media" '```' "Flutter markers: ${neg_hits:-NOT DETECTED}" "throwaway package removed, tree clean: $([[ $restored == 1 ]] && echo yes || echo NO)" '```'
if [[ "$restored" == 1 && "$n" -ge 50 && -z "$hits" && -n "$control" && -n "$neg_hits" ]]; then rows+=("| pure-Dart closure | PASS |"); else rows+=("| pure-Dart closure | **FAIL** |"); ok=0; fi

# 2. registration
if grep -qx '  - utility/mc_fixtures_identity' pubspec.yaml; then rows+=("| workspace registration | PASS |"); else rows+=("| workspace registration | **FAIL** |"); ok=0; fi

# 3. no production target reaches it
libs=""
for d in feature/*/*/ utility/mc_*/; do
  pkg="$(basename "$d")"
  case "$pkg" in
    mc_fixtures_*|mc_mocked_backend|mc_test_*|mc_e2e_utils|mc_ds_testing|mc_analysis) continue ;;
  esac
  [[ -f "$d/BUILD.bazel" ]] || continue
  libs="$libs //${d%/}:$pkg"
done
scan() {
  local l out hit
  for l in "$@"; do
    out="$(closure "$l")"
    if [[ -z "$out" ]]; then echo "$l -> QUERY RETURNED NOTHING"; continue; fi
    hit="$(grep -E '^@?@?//utility/mc_fixtures_identity' <<< "$out" | sort -u | head -3 | tr '\n' ' ')"
    [[ -z "$hit" ]] || echo "$l -> $hit"
  done
}
nlibs="$(wc -w <<< "$libs" | tr -d ' ')"
# shellcheck disable=SC2086
found="$(scan $libs)"
pos="$(closure //utility/mc_fixtures_identity:identity_test | grep -E '^@?@?//utility/mc_fixtures_identity' | sort -u | head -2 | tr '\n' ' ')"
make_neg feature/zz_negctl_T0061 "$neg_prod" zz_negctl_prod //utility/mc_fixtures_identity || true
neg="$(scan //$neg_prod:zz_negctl_prod)"
[[ " ${MADE[*]-} " == *" feature/zz_negctl_T0061 "* ]] && rm -rf feature/zz_negctl_T0061
restored2=1; [[ -z "$(git status --porcelain -- feature/zz_negctl_T0061)" && ! -e feature/zz_negctl_T0061 ]] || restored2=0
report "## fixtures check ($nlibs production targets scanned)" '```' \
  "identity dependencies: ${found:-none}" "positive control (its own test): ${pos:-nothing}" \
  "negative control (a throwaway production target depending on it): ${neg:-NOT DETECTED}" "throwaway package removed, tree clean: $([[ $restored2 == 1 ]] && echo yes || echo NO)" '```'
if [[ "$restored2" == 1 && -z "$found" && "$nlibs" -ge 20 && -n "$pos" && -n "$neg" && "$neg" != *"QUERY RETURNED NOTHING"* ]]; then
  rows+=("| fixtures check | PASS |")
else
  rows+=("| fixtures check | **FAIL** |"); ok=0
fi

# The negative controls must have been created (never silently skipped).
if [[ $neg_refused == 0 ]]; then rows+=("| negative controls created | PASS |"); else rows+=("| negative controls created | **FAIL** (a throwaway path already existed) |"); ok=0; fi

# 4. gates
# Two gates with their own logs, so the reported "Executed" line is the
# uncached identity run, not the cached repo-wide run after it.
gate "test identity (uncached)" bzw test --nocache_test_results //utility/mc_fixtures_identity/...
gate "test //... (--lockfile_mode=error)" bzw test --lockfile_mode=error //...
gate "build --config=lint //..." bzw build --config=lint //...
gate "mc_arch_check" bzw run //tool/mc_arch_check:bin
gate "rules_fork.sh check" "$REPO/tool/rules_fork.sh" check
gate "dart format" fvm dart format --output=none --set-exit-if-changed \
  app feature spike utility tool/l10n_check tool/mc_arch_check
gate "l10n_check" bzw run //tool/l10n_check:bin -- "$REPO"

# 5. coverage
coverage() {
  bzw coverage //utility/mc_fixtures_identity/... || return 1
  /usr/bin/python3 -I "$REPO/tool/checks/merge_lcov.py" \
    "$(bzw info output_path 2>/dev/null)" utility/mc_fixtures_identity "$MIN" | tee "$work/coverage.txt"
}
gate "coverage >= $MIN %" coverage
total=$(grep -a '^TOTAL' "$work/coverage.txt" 2>/dev/null || echo 'TOTAL not measured')
tests_line=$(plain "$(logname "test identity (uncached)")" 2>/dev/null | grep -a 'Executed' | tail -1)
all_line=$(plain "$(logname "test //... (--lockfile_mode=error)")" 2>/dev/null | grep -a 'Executed' | tail -1)

report "" "| Gate | Result |" "|---|---|" "${rows[@]}" "" \
  "- identity tests, uncached: ${tests_line:-?}" "- test //...: ${all_line:-?}" "- mc_fixtures_identity coverage: $total (threshold $MIN %)" \
  ${fails[@]+"${fails[@]}"}
finish T-0061-AC5-gates $([[ $ok -eq 1 ]] && echo 0 || echo 1)
