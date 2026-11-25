#!/bin/bash
# T-0032: each mutation breaks one behaviour an AC describes; the feature's
# tests must then FAIL. Every file is restored after its run.
#   documents/evidence/T-0032/engineer/mutations.sh [target ...]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
# Exit 1 if any mutation survives (its tests pass) or does not apply.
set -uo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$ROOT"
read -r -a STARTUP <<< "${MC_BAZEL_STARTUP:-}"
bz() { "$ROOT/tool/bazelw" ${STARTUP[@]+"${STARTUP[@]}"} "$@"; }
P=feature/characters/characters_list
L=$P/lib/src
TARGETS=("${@:-//$P:bdd_test}")

# id | file | old (literal) | new (literal) | what it breaks
MUTATIONS=(
  "M1|$L/presentation/bloc/characters_list_bloc.dart|_flow.update((s) => s.copyWith(previewId: id));|_flow.update((s) => s);|AC3 the tap opens no preview"
  "M2|$L/presentation/bloc/character_preview_bloc.dart|_navigator.openCharacter(state.id);|_navigator..openCharacter(state.id)..openCharacter(state.id);|AC3 openCharacter twice"
  "M3|$L/presentation/bloc/characters_list_bloc.dart|const int charactersPageSize = 30;|const int charactersPageSize = 20;|AC1/AC5 pages of 20"
  "M4|$L/domain/repository/characters_list_repository.dart|offset: q.offset,|offset: 0,|AC5 every page is page 1"
  "M5|$L/presentation/widget/failure_message.dart|ApiTimeout() => core.errorTimeout,|ApiTimeout() => core.errorGeneric,|AC2 timeout copy"
  "M6|$L/presentation/bloc/characters_list_bloc.dart|PagedState(items: [], failure: final failure?) =>|PagedState(items: [], failure: final failure?) when false =>|AC2 first-page failure shown as loading"
  "M7|$L/presentation/page/characters_list_page.dart|footerErrorMessage: l10n.charactersListLoadMoreFailed,|footerErrorMessage: l10n.charactersListEmptyMessage,|AC2 footer copy"
  "M8|$L/flow/characters_list_flow.dart|arguments: id,|arguments: null,|AC3 preview page without previewId"
  "M9|$L/l10n/characters_list_de.arb|\"charactersListTitle\": \"Figuren\",|\"charactersListTitle\": \"Characters\",|AC4 German title"
  "M10|$L/domain/model/character_mapper.dart|path: thumbnail.path,|path: 'mock-asset://characters/000',|AC1 wrong art"
  "M11|$L/domain/repository/characters_list_repository.dart|_loaded[character.id] = character;|_loaded.putIfAbsent(CharacterId(0), () => character);|AC3 preview of the wrong character"
  "M12|$L/flow/characters_list_flow.dart|const McFlowPage(name: 'list', child: CharactersListPage()),|McFlowPage(name: 'list', child: CharactersListPage(key: UniqueKey())),|AC3 list rebuilt on back (scroll lost)"
)

status=0
for m in "${MUTATIONS[@]}"; do
  IFS='|' read -r id file old new what <<< "$m"
  cp "$file" "$file.orig"
  if ! /usr/bin/python3 -I - "$file" "$old" "$new" <<'EOF'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
if s.count(old) != 1:
    sys.exit(1)
open(p, "w").write(s.replace(old, new))
EOF
  then
    echo "$id NOT APPLIED ($what): '$old' not found exactly once in $file"
    status=1; mv "$file.orig" "$file"; continue
  fi
  if bz test "${TARGETS[@]}" > "/tmp/mc-T-0032-$id.log" 2>&1; then
    echo "$id SURVIVED ($what)"; status=1
  else
    if grep -a -q 'FAILED TO BUILD\|Build did NOT complete' "/tmp/mc-T-0032-$id.log"; then
      echo "$id DID NOT COMPILE ($what): a build failure proves nothing"; status=1
    else
      failed=$(grep -a -E '^\s+FAIL ' "$(bz info bazel-testlogs 2>/dev/null)/$P/bdd_test/test.log" 2>/dev/null | wc -l | tr -d ' ')
      echo "$id killed ($what): ${failed} failing scenario(s)"
    fi
  fi
  mv "$file.orig" "$file"
done
git diff --quiet -- "$P" || { echo "WORKTREE NOT RESTORED"; status=1; }
exit $status
