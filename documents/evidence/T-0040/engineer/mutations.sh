#!/bin/bash
# T-0040 mutation check: each mutation of mc_ds_navigation must make a test
# fail (a mutation that survives means a test does not prove its claim).
# The unmutated tree must pass first (positive control). Each mutation is
# restored afterwards, and the restore is verified with `git diff --quiet`.
#   MC_OB=/tmp/mc-ob-T-0040-engineer documents/evidence/T-0040/engineer/mutations.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
OB="${MC_OB:-/tmp/mc-ob-T-0040-engineer}"
bz() { tool/bazelw --output_base="$OB" "$@"; }
LIB=utility/mc_ds_navigation/lib/src
T=//utility/mc_ds_navigation:navigation_test
rc=0
restore() { git checkout -- "$LIB"; }
trap restore EXIT

run() { bz test "$T" --nocache_test_results --test_output=errors 2>&1 | tr '\r' '\n'; }

base="$(run)"
if ! grep -q "PASSED" <<< "$base"; then echo "BASELINE FAILS"; echo "$base" | tail -20; exit 1; fi
echo "baseline: PASS"

# mutate <name> <file> <python expression on s>
mutate() {
  local name="$1" file="$2" expr="$3"
  python3 - "$file" "$expr" <<'EOF'
import sys
p, expr = sys.argv[1], sys.argv[2]
s = open(p).read()
t = eval(expr)
if t == s:
    print("MUTATION DID NOT CHANGE THE FILE"); sys.exit(3)
open(p, "w").write(t)
EOF
  if [[ $? -ne 0 ]]; then echo "$name: NOT APPLIED"; rc=1; restore; return; fi
  fvm dart format "$LIB" > /dev/null
  out="$(run)"
  # Killed only by a failing test, not by a build, format or analyze error.
  if grep -q "^  FAIL " <<< "$out"; then
    echo "$name: KILLED ($(grep -a -m1 '  FAIL ' <<< "$out" | sed 's/^ *//'))"
  else
    echo "$name: SURVIVED"; rc=1
  fi
  restore
  git diff --quiet -- "$LIB" || { echo "RESTORE FAILED"; rc=1; }
}

mutate "title not a header (app bar)" $LIB/mc_app_bar.dart \
  "s.replace('Semantics(\n              header: true,', 'Semantics(\n              header: false,')"
mutate "section title not a header" $LIB/mc_section_header.dart \
  "s.replace('header: true', 'header: false')"
mutate "tab not selectable (selected flag dropped)" $LIB/mc_tab_bar.dart \
  "s.replace('selected: widget.selected,\n      button', 'button')"
mutate "tab role dropped" $LIB/mc_tab_bar.dart \
  "s.replace('role: SemanticsRole.tab,', '')"
mutate "tab min size below 44" $LIB/mc_tab_bar.dart \
  "s.replace('minWidth: mcMinTapTarget,\n            minHeight: McTabBar.height,', 'minWidth: 10,\n            minHeight: 20,')"
mutate "tab bar always fills (no scroll)" $LIB/mc_tab_bar.dart \
  "s.replace('scrollDirection: Axis.horizontal,', 'scrollDirection: Axis.vertical,')"
mutate "selected tab not revealed" $LIB/mc_tab_bar.dart \
  "s.replace('alignment: 0.5,', 'alignment: 0.5,\n          duration: Duration.zero,').replace('Scrollable.ensureVisible(', 'Future<void>.value(')"
mutate "leading ignored" $LIB/mc_app_bar.dart \
  "s.replace('leading: leading,', '')"
mutate "large title scale uncapped" $LIB/mc_app_bar.dart \
  "s.replace('.clamp(maxScaleFactor: McAppBar.largeTitleMaxScale)', '')"
mutate "large band not in preferredSize" $LIB/mc_app_bar.dart \
  "s.replace('(largeTitle ? largeTitleExtent : 0)', '0')"
mutate "section action hit area below 44" $LIB/mc_section_header.dart \
  "s.replace('minimumSize: const Size(mcMinTapTarget, mcMinTapTarget),', 'minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,')"
mutate "tab tap does not report" $LIB/mc_tab_bar.dart \
  "s.replace('onTap: () => onChanged(i),', 'onTap: () {},')"
echo "overall: $([[ $rc == 0 ]] && echo 'all mutations killed' || echo 'SOME SURVIVED OR FAILED')"
exit $rc
