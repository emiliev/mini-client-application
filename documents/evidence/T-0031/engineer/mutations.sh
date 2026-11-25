#!/bin/bash
# T-0031 fix round: each mutation breaks one fix, runs the named target
# uncached, prints the FAILING test names, and restores the file from git.
# A mutation that does not change the file, or whose target still passes,
# is reported as PROOF-FAILED and makes the script exit 1.
#   MC_OUTPUT_BASE=/tmp/mc-ob-T-0031-engineer documents/evidence/T-0031/engineer/mutations.sh
set -u
REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO"
OB="${MC_OUTPUT_BASE:-/tmp/mc-ob-T-0031-engineer}"
status=0
# flutter_test prints `  FAIL  name`; package:test prints `00:00 +1 -1: name [E]`.
FAILPAT='^\s+FAIL\s|^[0-9:]+ \+[0-9]+ -[0-9]+: .*\[E\]$'
mutate() {  # name file perl-substitution target...
  local name="$1" file="$2" subst="$3"; shift 3
  cp "$file" /tmp/mc-t31-mut.bak
  perl -0pi -e "$subst" "$file"
  if cmp -s "$file" /tmp/mc-t31-mut.bak; then
    echo "[$name] PROOF-FAILED: mutation did not apply"; status=1; return
  fi
  local out
  out="$(tool/bazelw --output_base="$OB" test --nocache_test_results --test_output=all "$@" 2>&1 | tr '\r' '\n')"
  cp /tmp/mc-t31-mut.bak "$file"
  local fails
  fails="$(grep -E "$FAILPAT" <<< "$out" | sed 's/^ *//' | sort -u | head -12)"
  if [[ -z "$fails" ]]; then
    echo "[$name] PROOF-FAILED: no test failed"; status=1
  else
    echo "[$name] failing tests:"; sed 's/^/    /' <<< "$fails"
  fi
}
L=utility/mc_ds_lists/lib/src/paged_body.dart
LISTS="//utility/mc_ds_lists:paged_list_test //utility/mc_ds_lists:paged_grid_test"
for t in 0.5 0.6 0.75 0.95; do
  mutate "threshold $t" $L "s/mcPagedLoadMoreThreshold = 0.8;/mcPagedLoadMoreThreshold = $t;/" $LISTS --keep_going
done
mutate "no post-frame check on state change" $L 's/      _requested = false;\n      \/\/ A page that.*?_scheduleCheck\(\);/      _requested = false;/s' $LISTS --keep_going
mutate "no latch reset below threshold" $L 's/    if \(!_pastThreshold\(m\)\) \{\n      _requested = false;\n    \} else if/    if (!_pastThreshold(m)) {\n    } else if/' $LISTS --keep_going
mutate "skeleton not excluded" $L 's/excludeSemantics: true,\n              sliver: skeleton/excludeSemantics: false,\n              sliver: skeleton/' $LISTS --keep_going
mutate "card always a button" utility/mc_ds_cards/lib/src/mc_media_card.dart 's/button: onTap != null,/button: true,/' //utility/mc_ds_cards:card_test
mutate "skeleton card announces" utility/mc_ds_cards/lib/src/mc_media_card.dart 's/return ExcludeSemantics\(child: card\);/return Semantics(label: "Loading", child: card);/' //utility/mc_ds_cards:card_test
mutate "McImage swallows Error" utility/mc_ds_media/lib/src/mc_image.dart 's/on Exception catch/on Object catch/' //utility/mc_ds_media:image_test
mutate "paging Error leaves isLoadingMore" utility/mc_paging/lib/src/paging_controller.dart 's/        _emit\(_state.copyWith\(isLoadingMore: false\)\);\n      \}\n      rethrow/      }\n      rethrow/' //utility/mc_paging:paging_controller_test
# Test-side mutation: the old default cell (width / 0.75) clips the text.
mutate "grid cell too short (old default)" utility/mc_ds_lists/test/paged_grid_test.dart 's/cellHeight: \(width, scaler\) =>\n\s+McMediaCard.heightFor\(width: width, textScaler: scaler\),/cellHeight: (width, scaler) => width \/ 0.75,/' //utility/mc_ds_lists:paged_grid_test
# Purity: a Flutter import anywhere under lib/ must fail the purity test.
probe=utility/mc_media/lib/src/probe.dart
printf "import 'package:flutter/widgets.dart';\n" > "$probe"
out="$(tool/bazelw --output_base="$OB" test --nocache_test_results --test_output=all //utility/mc_media:purity_test 2>&1 | tr '\r' '\n')"
rm -f "$probe"
if grep -qE "$FAILPAT" <<< "$out"; then echo "[flutter import probe] failing tests:"; grep -E "$FAILPAT" <<< "$out" | sed 's/^ */    /' | sort -u | head -5; else echo "[flutter import probe] PROOF-FAILED"; status=1; fi
exit $status
