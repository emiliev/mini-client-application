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

# id | file | old (literal) | new (literal) | what it breaks | [target]
# The target defaults to //$P:bdd_test (or the script's arguments).
# F1-F7 are the T-0032 fix round's "fails without the fix" proofs.
MUTATIONS=(
  "M1|$L/presentation/bloc/characters_list_bloc.dart|_flow.update((s) => s.copyWith(preview: character));|_flow.update((s) => s);|AC3 the tap opens no preview"
  "M2|$L/presentation/bloc/character_preview_bloc.dart|_navigator.openCharacter(state.id);|_navigator..openCharacter(state.id)..openCharacter(state.id);|AC3 openCharacter twice"
  "M3|$L/presentation/bloc/characters_list_bloc.dart|const int charactersPageSize = 30;|const int charactersPageSize = 20;|AC1/AC5 pages of 20"
  "M4|$L/domain/repository/characters_list_repository.dart|offset: q.offset,|offset: 0,|AC5 every page is page 1"
  "M5|$L/presentation/widget/failure_message.dart|ApiTimeout() => core.errorTimeout,|ApiTimeout() => core.errorGeneric,|AC2 timeout copy"
  "M6|$L/presentation/bloc/characters_list_bloc.dart|PagedState(items: [], failure: final failure?) =>|PagedState(items: [], failure: final failure?) when false =>|AC2 first-page failure shown as loading"
  "M7|$L/presentation/page/characters_list_page.dart|footerErrorMessage: l10n.charactersListLoadMoreFailed,|footerErrorMessage: l10n.charactersListEmptyMessage,|AC2 footer copy"
  "M8|$L/flow/characters_list_flow.dart|arguments: character.id,|arguments: null,|AC3 preview page without the selected id"
  "M9|$L/l10n/characters_list_de.arb|\"charactersListTitle\": \"Figuren\",|\"charactersListTitle\": \"Characters\",|AC4 German title"
  "M10|$L/domain/model/character_mapper.dart|path: thumbnail.path,|path: 'mock-asset://characters/000',|AC1 wrong art"
  "M11|$L/presentation/widget/character_tile.dart|CharactersListEvent.preview(character),|CharactersListEvent.preview(character.copyWith(name: 'X')),|AC3 preview of the wrong character"
  "M12|$L/flow/characters_list_flow.dart|const McFlowPage(name: 'list', child: CharactersListPage()),|McFlowPage(name: 'list', child: CharactersListPage(key: UniqueKey())),|AC3 list rebuilt on back (scroll lost)"
  "F1|$L/presentation/bloc/characters_list_bloc.dart|if (_flow.state.preview == null) {|if (_flow.state.preview == null \|\| character.name.isNotEmpty) {|item 3: a second tap replaces the open preview"
  "F2|$L/flow/characters_list_flow.dart|key: ValueKey(character.id),|key: null,|item 3: the preview page is not keyed by the id"
  "F3a|utility/mc_test_utils/lib/src/backend_harness.dart|    _failRules.clear();\n    backend.useScenario(null);|    backend.reset();|item 4: recover() as the old step did it (engine reset, harness mirrors kept)|//utility/mc_test_utils:harness_test"
  "F3b|utility/mc_test_utils/lib/src/backend_harness.dart|      rule.live = false;|      rule.live = true;|item 4: recover() leaves the engine-side rules live|//utility/mc_test_utils:harness_test"
  "F4|$L/flow/characters_list_flow.dart|key: ValueKey(initialTeamId),|key: null,|item 7: a new team keeps the old flow|//$P:flow_scope_test"
  "F5|utility/mc_fixtures_characters/lib/src/data/universe.dart|final width = math.max(2, '\$count'.length);|final width = math.min(2, '\$count'.length);|item 12: two-digit names past 99|//utility/mc_fixtures_characters:fixture_sets_test"
  "F6|$P/test/architecture/architecture_test.dart|\\s+['\"](package:flutter|\\s+'(package:flutter|item 11: a single-quote-only import check|//$P:architecture_test"
)

status=0
for m in "${MUTATIONS[@]}"; do
  # Fields are separated by an unescaped `|`; `\|` is a literal bar.
  IFS=$'\x1f' read -r id file old new what target <<< "$(sed 's/\\|/\x1e/g; s/|/\x1f/g; s/\x1e/|/g' <<< "$m")"
  if [[ -n "$target" ]]; then targets=("$target"); else targets=("${TARGETS[@]}"); fi
  cp "$file" "$file.orig"
  if ! /usr/bin/python3 -I - "$file" "$old" "$new" <<'EOF'
import sys
p = sys.argv[1]
old, new = (a.replace("\\n", "\n") for a in sys.argv[2:4])
s = open(p).read()
if s.count(old) != 1:
    sys.exit(1)
open(p, "w").write(s.replace(old, new))
EOF
  then
    echo "$id NOT APPLIED ($what): '$old' not found exactly once in $file"
    status=1; mv "$file.orig" "$file"; continue
  fi
  if bz test --nocache_test_results "${targets[@]}" > "/tmp/mc-T-0032-$id.log" 2>&1; then
    echo "$id SURVIVED ($what)"; status=1
  else
    if grep -a -q 'FAILED TO BUILD\|Build did NOT complete' "/tmp/mc-T-0032-$id.log"; then
      echo "$id DID NOT COMPILE ($what): a build failure proves nothing"; status=1
    else
      t="${targets[0]#//}"; log="$(bz info bazel-testlogs 2>/dev/null)/${t/://}/test.log"
      failed=$(grep -a -E '^\s+FAIL ' "$log" 2>/dev/null | sed 's/^ *FAIL  //' | head -3 | paste -sd ';' -)
      echo "$id killed ($what): ${failed:-a failing test}"
    fi
  fi
  mv "$file.orig" "$file"
done
git diff --quiet -- "$P" utility || { echo "WORKTREE NOT RESTORED"; status=1; }
exit $status
