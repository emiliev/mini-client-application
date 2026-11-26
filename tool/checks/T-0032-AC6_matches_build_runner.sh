#!/bin/bash
# T-0032-AC6: characters_list's Bazel codegen equals build_runner's, byte for
# byte: the retrofit API, the DTO (freezed + json), the domain model, the flow
# state and the bloc state (spike_reference.sh), and the injectable
# .config.dart plus every shard (injectable_reference.sh). Both overlays get
# only the Flutter-free generator inputs (`:_stage`, R15), as Bazel does.
#
# PASS only if both scripts exit 0 (a failed Bazel build, drift or an
# unresolved import is a FAIL) and exactly the files below are EQUAL; a file
# that differs, is missing, or is not on the list fails.
#   tool/checks/T-0032-AC6_matches_build_runner.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
PKG=feature/characters/characters_list
EXPECTED=(
  "$PKG/lib/src/di/di_initializer.config.dart"
  "$PKG/lib/src/domain/api/characters_list_api.g.dart"
  "$PKG/lib/src/domain/api/characters_list_api.injectable.json"
  "$PKG/lib/src/domain/model/character.freezed.dart"
  "$PKG/lib/src/domain/model/character_dto.freezed.dart"
  "$PKG/lib/src/domain/model/character_dto.g.dart"
  "$PKG/lib/src/domain/repository/characters_list_repository.injectable.json"
  "$PKG/lib/src/flow/characters_list_flow_state.freezed.dart"
  "$PKG/lib/src/presentation/bloc/character_preview_bloc.injectable.json"
  "$PKG/lib/src/presentation/bloc/characters_list_bloc.freezed.dart"
  "$PKG/lib/src/presentation/bloc/characters_list_bloc.injectable.json"
  # T-0041: the preview's related comics.
  "$PKG/lib/src/domain/model/related_comic.freezed.dart"
  "$PKG/lib/src/presentation/bloc/related_comics_bloc.freezed.dart"
  "$PKG/lib/src/presentation/bloc/related_comics_bloc.injectable.json"
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

report "# T-0032-AC6: characters_list codegen vs build_runner" "" \
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
finish T-0032-AC6-byte-identity $([[ $ok -eq 1 ]] && echo 0 || echo 1)
