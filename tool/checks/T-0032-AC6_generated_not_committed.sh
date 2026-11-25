#!/bin/bash
# T-0032-AC6: every generated file of characters_list comes from a Bazel
# action and none is committed.
#
# 1. `git ls-files` (the index, so a staged file counts) holds no generated
#    file under the package: *.g.dart, *.freezed.dart, *.config.dart,
#    *.injectable.json, lib/src/l10n/*_l10n*.dart, test/feature/*_test.dart.
# 2. Each kind (retrofit .g.dart, json .g.dart, freezed, injectable config and
#    shards, gen-l10n, the generated BDD tests and their main) is a declared output of a Bazel
#    target of the package (cquery --output=files): the build makes them.
# 3. The root .gitignore ignores every kind, so an IDE / build_runner run
#    cannot add one by accident.
#   tool/checks/T-0032-AC6_generated_not_committed.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
PKG=feature/characters/characters_list
GEN='(\.g\.dart|\.freezed\.dart|\.config\.dart|\.injectable\.json|/lib/src/l10n/[^/]*_l10n[^/]*\.dart|/test/feature/[^/]*_test\.dart)$'

committed=$(git ls-files -- "$PKG" | grep -E "$GEN" || true)
outputs=$(bzw cquery --output=files "kind('dart_codegen|dart_aggregate_codegen|dart_sqlcodegen|flutter_gen_l10n|bdd_suite_main', //$PKG:*)" 2>/dev/null \
  | sed -n "s|^.*/bin/$PKG/||p" | sort -u)
kinds=(
  "retrofit client|lib/src/domain/api/characters_list_api.g.dart"
  "json part|lib/src/domain/model/character_dto.g.dart"
  "freezed (DTO)|lib/src/domain/model/character_dto.freezed.dart"
  "freezed (domain)|lib/src/domain/model/character.freezed.dart"
  "freezed (flow state)|lib/src/flow/characters_list_flow_state.freezed.dart"
  "freezed (bloc state)|lib/src/presentation/bloc/characters_list_bloc.freezed.dart"
  "injectable config|lib/src/di/di_initializer.config.dart"
  "injectable shard|lib/src/presentation/bloc/characters_list_bloc.injectable.json"
  "gen-l10n|lib/src/l10n/characters_list_l10n.dart"
  "BDD test|test/feature/characters_list_test.dart"
  "BDD test|test/feature/characters_list_paging_test.dart"
  "BDD main|test/feature/bdd_test_main.dart|bazel-only"
)
rows=()
declared_ok=1
ignored_ok=1
for k in "${kinds[@]}"; do
  IFS='|' read -r label rel scope <<< "$k"
  declared=no; grep -qxF "$rel" <<< "$outputs" && declared=yes || declared_ok=0
  # The BDD aggregator main exists only in bazel-out: no IDE or build_runner
  # path writes it into the source tree, so it needs no ignore rule.
  if [[ "$scope" == bazel-only ]]; then ignored="n/a (bazel-out only)"
  else ignored=no; git check-ignore -q --no-index "$PKG/$rel" && ignored=yes || ignored_ok=0; fi
  rows+=("| $label | \`$rel\` | $declared | $ignored |")
done

report "# T-0032-AC6: generated files are Bazel outputs, never committed" "" \
  "Generated files in the git index under \`$PKG\`: ${committed:-none}" "" \
  "| Kind | File (package-relative) | declared Bazel output | git-ignored |" "|---|---|---|---|" \
  "${rows[@]}" "" \
  "All declared outputs of the package's generator targets ($(grep -c . <<< "$outputs")):" "" '```' "$outputs" '```'
ok=1
[[ -z "$committed" ]] || ok=0
[[ -n "$outputs" && $declared_ok -eq 1 && $ignored_ok -eq 1 ]] || ok=0
finish T-0032-AC6-not-committed $([[ $ok -eq 1 ]] && echo 0 || echo 1)
