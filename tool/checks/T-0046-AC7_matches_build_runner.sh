#!/bin/bash
# T-0046-AC7: discovery_search's Bazel codegen equals build_runner's, byte for
# byte: the retrofit API, the DTOs (freezed + json), the domain model, the flow
# state and the bloc state (spike_reference.sh), and the injectable
# .config.dart plus every shard, the DI module's included
# (injectable_reference.sh). Both overlays get
# only the Flutter-free generator inputs (`:_stage`, R15), as Bazel does.
#
# PASS only if both scripts exit 0 (a failed Bazel build, drift or an
# unresolved import is a FAIL) and exactly the files below are EQUAL; a file
# that differs, is missing, or is not on the list fails.
#   tool/checks/T-0046-AC7_matches_build_runner.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
PKG=feature/discovery/discovery_search
EXPECTED=(
  "$PKG/lib/src/di/di_initializer.config.dart"
  "$PKG/lib/src/di/di_module.injectable.json"
  "$PKG/lib/src/domain/api/discovery_search_api.g.dart"
  "$PKG/lib/src/domain/api/discovery_search_api.injectable.json"
  "$PKG/lib/src/domain/model/search_dto.freezed.dart"
  "$PKG/lib/src/domain/model/search_dto.g.dart"
  "$PKG/lib/src/domain/model/search_results.freezed.dart"
  "$PKG/lib/src/domain/repository/discovery_search_repository.injectable.json"
  "$PKG/lib/src/flow/discovery_search_flow_state.freezed.dart"
  "$PKG/lib/src/presentation/bloc/discovery_search_bloc.freezed.dart"
  "$PKG/lib/src/presentation/bloc/discovery_search_bloc.injectable.json"
)
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export MC_REF_SRCS_FROM="//$PKG:_stage"
"$REPO/tool/build_runner_overlay/spike_reference.sh" "$PKG" > "$TMP/ref.log" 2>&1; ref_rc=$?
"$REPO/tool/build_runner_overlay/injectable_reference.sh" "$PKG" > "$TMP/inj.log" 2>&1; inj_rc=$?
cat "$TMP/ref.log" "$TMP/inj.log" > "$TMP/all.log"
equal=$(grep -a -E '^EQUAL ' "$TMP/all.log" | awk '{print $2}' | sort)
expected=$(printf '%s\n' "${EXPECTED[@]}" | sort)
missing=$(comm -13 <(printf '%s\n' "$equal") <(printf '%s\n' "$expected"))
extra=$(comm -23 <(printf '%s\n' "$equal") <(printf '%s\n' "$expected"))

report "# T-0046-AC7: discovery_search codegen vs build_runner" "" \
  "Overlay inputs: \`$MC_REF_SRCS_FROM\` (plus the init file for injectable)." "" '```' \
  "$(grep -a -v -E '^\s*[0-9]+s (source_gen|freezed|json_serializable|retrofit_generator|go_router_builder|injectable_generator|build_runner)|first-party path dep' "$TMP/all.log")" '```' "" \
  "| Check | Result |" "|---|---|" \
  "| spike_reference.sh (freezed, json, retrofit) | exit $ref_rc |" \
  "| injectable_reference.sh (config + shards) | exit $inj_rc |" \
  "| expected files EQUAL | $(grep -c . <<< "$equal") of ${#EXPECTED[@]} |" \
  "| expected but not EQUAL | ${missing:-none} |" \
  "| EQUAL but not on the list | ${extra:-none} |"
ok=1
[[ $ref_rc -eq 0 && $inj_rc -eq 0 ]] || ok=0
[[ "$equal" == "$expected" ]] || ok=0
grep -q -a -E '^(DIFFER|MISSING|DRIFT|BAZEL BUILD FAILED|FAIL|UNRESOLVED)' "$TMP/all.log" && ok=0
finish T-0046-AC7-byte-identity $([[ $ok -eq 1 ]] && echo 0 || echo 1)
