#!/bin/bash
# T-0052-AC5 (and AC4's purity and fixtures checks): mc_feature_flags and
# mc_fixtures_platform are pure Dart, registered, covered at >= 90 %, and no
# production target reaches the fixtures; plus the repo gates.
#   1. closure of both packages has no Flutter markers (as T-0030-AC7).
#      Positive control: the closure of //utility/mc_fixtures_media has them,
#      so a query that cannot see Flutter fails the check. Negative control:
#      a throwaway target that depends on the package under test and on the
#      media package shows them.
#   2. workspace registration in the root pubspec.yaml
#   3. fixtures check: no production feature or utility target reaches
#      mc_fixtures_platform (T-0031-AC6 scan). Positive control: a test target
#      of mc_feature_flags does. Negative control: a throwaway production
#      target that depends on it is detected. Neither control edits a tracked
#      file.
#   4. gates: test //..., lint, mc_arch_check, rules_fork.sh check, format,
#      l10n_check
#   5. coverage of each package's lib/ >= MC_COVERAGE_MIN (default 90)
#   tool/checks/T-0052-AC5_gates.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
MIN="${MC_COVERAGE_MIN:-90}"
FLUTTER='sky_engine|flutter_ios_engine|pub_deps__flutter[_a-z]*//|pub_deps__flutter_test|@@rules_flutter|//flutter:'
work="$(mktemp -d)"
# The negative controls never edit a tracked file: each builds a throwaway,
# untracked Bazel package (removed by the trap, and `git status` must be clean
# of it afterwards) that depends on the package under test.
neg_flutter_ff=utility/zz_negctl_T0052_flutter_ff
neg_flutter_fp=utility/zz_negctl_T0052_flutter_fp
neg_prod=feature/zz_negctl_T0052/zz_negctl_T0052_prod
make_neg() {  # make_neg <dir> <package> <dep>...
  local dir="$1" pkg="$2"; shift 2
  [[ ! -e "$dir" ]] || { echo "refusing: $dir exists" >&2; return 1; }
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
cleanup() { rm -rf "$neg_flutter_ff" "$neg_flutter_fp" feature/zz_negctl_T0052 "$work"; }
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

# 1. purity of both packages
control="$(closure //utility/mc_fixtures_media:mc_fixtures_media | grep -E "$FLUTTER" | sort -u | head -3)"
report "# T-0052-AC5: pure Dart, registered, covered" "" \
  "## positive control: the closure of mc_fixtures_media" '```' "Flutter markers: ${control:-none}" '```'
purity() {  # purity <package> <neg dir>
  local pkg="$1" neg="$2" deps n hits neg_hits restored
  deps="$(closure "//utility/$pkg:$pkg")"
  n="$(grep -c . <<< "$deps")"
  hits="$(grep -E "$FLUTTER" <<< "$deps" | sort -u | head -5)"
  make_neg "$neg" "zz_negctl_$pkg" "//utility/$pkg" //utility/mc_fixtures_media
  neg_hits="$(closure "//$neg:zz_negctl_$pkg" | grep -E "$FLUTTER" | sort -u | head -3)"
  rm -rf "$neg"
  restored=1; [[ -z "$(git status --porcelain -- "$neg")" && ! -e "$neg" ]] || restored=0
  report "## closure of $pkg ($n targets)" '```' "Flutter markers: ${hits:-none}" '```' \
    "## negative control: a throwaway target depending on $pkg and on mc_fixtures_media" '```' \
    "Flutter markers: ${neg_hits:-NOT DETECTED}" "throwaway package removed, tree clean: $([[ $restored == 1 ]] && echo yes || echo NO)" '```'
  if [[ "$restored" == 1 && "$n" -ge 40 && -z "$hits" && -n "$control" && -n "$neg_hits" ]]; then
    rows+=("| pure-Dart closure: $pkg | PASS |")
  else
    rows+=("| pure-Dart closure: $pkg | **FAIL** |"); ok=0
  fi
}
purity mc_fixtures_platform "$neg_flutter_fp"
purity mc_feature_flags "$neg_flutter_ff"

# 2. registration
for pkg in mc_feature_flags mc_fixtures_platform; do
  if grep -qx "  - utility/$pkg" pubspec.yaml; then rows+=("| workspace registration: $pkg | PASS |"); else rows+=("| workspace registration: $pkg | **FAIL** |"); ok=0; fi
done

# 3. no production target reaches the fixtures
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
    hit="$(grep -E '^@?@?//utility/mc_fixtures_platform' <<< "$out" | sort -u | head -3 | tr '\n' ' ')"
    [[ -z "$hit" ]] || echo "$l -> $hit"
  done
}
nlibs="$(wc -w <<< "$libs" | tr -d ' ')"
# shellcheck disable=SC2086
found="$(scan $libs)"
pos="$(closure //utility/mc_feature_flags:session_fetch_test | grep -E '^@?@?//utility/mc_fixtures_platform' | sort -u | head -2 | tr '\n' ' ')"
make_neg "$neg_prod" zz_negctl_prod //utility/mc_fixtures_platform
neg="$(scan //$neg_prod:zz_negctl_prod)"
rm -rf feature/zz_negctl_T0052
restored2=1; [[ -z "$(git status --porcelain -- feature/zz_negctl_T0052)" && ! -e feature/zz_negctl_T0052 ]] || restored2=0
report "## fixtures check ($nlibs production targets scanned)" '```' \
  "mc_fixtures_platform dependencies: ${found:-none}" "positive control (a test of mc_feature_flags): ${pos:-nothing}" \
  "negative control (a throwaway production target depending on it): ${neg:-NOT DETECTED}" "throwaway package removed, tree clean: $([[ $restored2 == 1 ]] && echo yes || echo NO)" '```'
if [[ "$restored2" == 1 && -z "$found" && "$nlibs" -ge 20 && -n "$pos" && -n "$neg" && "$neg" != *"QUERY RETURNED NOTHING"* ]]; then
  rows+=("| fixtures check | PASS |")
else
  rows+=("| fixtures check | **FAIL** |"); ok=0
fi

# 4. gates
# Separate gates with their own logs, so the reported "Executed" line is the
# uncached run of the two packages, not the cached repo-wide run after it.
gate "test both packages (uncached)" bzw test --nocache_test_results //utility/mc_feature_flags/... //utility/mc_fixtures_platform/...
gate "test //..." bzw test //...
gate "build --config=lint //..." bzw build --config=lint //...
gate "mc_arch_check" bzw run //tool/mc_arch_check:bin
gate "rules_fork.sh check" "$REPO/tool/rules_fork.sh" check
gate "dart format" fvm dart format --output=none --set-exit-if-changed \
  app feature spike utility tool/l10n_check tool/mc_arch_check
gate "l10n_check" bzw run //tool/l10n_check:bin -- "$REPO"
gate "sim apps build (--config=sim)" bzw build --config=sim //app/mini_client:mini_client_ios //app/sandbox/universe_sandbox:universe_sandbox_ios

# 5. coverage
coverage() {
  bzw coverage //utility/mc_feature_flags/... //utility/mc_fixtures_platform/... || return 1
  local rc=0 pkg
  for pkg in mc_feature_flags mc_fixtures_platform; do
    /usr/bin/python3 -I "$REPO/tool/checks/merge_lcov.py" \
      "$(bzw info output_path 2>/dev/null)" "utility/$pkg" "$MIN" | tee -a "$work/coverage.txt" || rc=1
  done
  return "$rc"
}
gate "coverage >= $MIN %" coverage
totals=$(grep -a '^TOTAL' "$work/coverage.txt" 2>/dev/null | tr '\n' ' ' || echo 'TOTAL not measured')
tests_line=$(plain "$(logname "test both packages (uncached)")" 2>/dev/null | grep -a 'Executed' | tail -1)
all_line=$(plain "$(logname "test //...")" 2>/dev/null | grep -a 'Executed' | tail -1)

report "" "| Gate | Result |" "|---|---|" "${rows[@]}" "" \
  "- the two packages' tests, uncached: ${tests_line:-?}" "- test //...: ${all_line:-?}" \
  "- coverage (mc_feature_flags, then mc_fixtures_platform): ${totals:-?} (threshold $MIN %)" \
  ${fails[@]+"${fails[@]}"}
finish T-0052-AC5-gates $([[ $ok -eq 1 ]] && echo 0 || echo 1)
