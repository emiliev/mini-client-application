#!/bin/bash
# T-0040 mutation check: each mutation of mc_ds_navigation must make a test
# fail (a mutation that survives means a test does not prove its claim).
# The unmutated tree must pass first (positive control). Each mutation is
# restored afterwards, and the restore is verified with `git diff --quiet`.
# The script REFUSES to run when the package's lib has uncommitted edits,
# because restoring a mutation is a `git checkout` of that folder.
#   MC_OB=/tmp/mc-ob-T-0040-engineer documents/evidence/T-0040/engineer/mutations.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
OB="${MC_OB:-/tmp/mc-ob-T-0040-engineer}"
bz() { tool/bazelw --output_base="$OB" "$@"; }
LIB=utility/mc_ds_navigation/lib/src
T=//utility/mc_ds_navigation:navigation_test
rc=0

if ! git diff --quiet -- "$LIB" || ! git diff --cached --quiet -- "$LIB"; then
  echo "REFUSING TO RUN: $LIB has uncommitted edits (commit them first)"
  exit 2
fi

restore() { git checkout -- "$LIB"; }
trap restore EXIT

run() { bz test "$T" --nocache_test_results --test_output=errors 2>&1 | tr '\r' '\n'; }

base="$(run)"
if ! grep -q "PASSED" <<< "$base"; then echo "BASELINE FAILS"; echo "$base" | tail -20; exit 1; fi
echo "baseline: PASS"

# mutate <name> <file> <python expression on s; `re` is available>
mutate() {
  local name="$1" file="$2" expr="$3"
  python3 -I - "$file" "$expr" <<'EOF'
import re, sys
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

APP=$LIB/mc_app_bar.dart
TAB=$LIB/mc_tab_bar.dart
SEC=$LIB/mc_section_header.dart

mutate "large title not a header" $APP \
  "re.sub(r'(Semantics\(\s*header: )true', r'\1false', s)"
mutate "large title does not name the route" $APP "s.replace('namesRoute: true,', '')"
mutate "large title scale uncapped" $APP \
  "s.replace('.clamp(maxScaleFactor: McAppBar.largeTitleMaxScale)', '')"
mutate "large band not in preferredSize" $APP \
  "s.replace('(largeTitle ? largeTitleExtent : 0)', '0')"
mutate "leading ignored" $APP "s.replace('leading: leading,', '')"
mutate "McAppBar.bottom dropped" $APP "s.replace('bottom: under,', 'bottom: largeTitle ? under : null,')"
mutate "McAppBar.bottom not in preferredSize" $APP \
  "s.replace(' + (bottom?.preferredSize.height ?? 0)', '')"

mutate "section title not a header" $SEC "s.replace('header: true', 'header: false')"
mutate "section action not flexible (long label overflows)" $SEC \
  "re.sub(r'Flexible\(\s*child:', 'Padding(padding: EdgeInsets.zero, child:', s)"
mutate "section action hit area below 44" $SEC \
  "s.replace('minimumSize: const Size(mcMinTapTarget, mcMinTapTarget),', 'minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,')"

mutate "tab selected flag dropped" $TAB "s.replace('selected: selected,\n      button', 'button')"
mutate "tab button flag dropped" $TAB "s.replace('button: true,', '')"
mutate "tab role dropped" $TAB "s.replace('role: SemanticsRole.tab,', '')"
mutate "tab min size below 44" $TAB \
  "s.replace('minWidth: mcMinTapTarget,\n            minHeight: McTabBar.height,\n            maxHeight: McTabBar.height,', 'minWidth: 10,\n            minHeight: 20,\n            maxHeight: 20,')"
mutate "tab bar does not scroll" $TAB "s.replace('scrollDirection: Axis.horizontal,', 'scrollDirection: Axis.vertical,')"
mutate "tab tap does not report" $TAB "s.replace('onTap: () => widget.onChanged(i),', 'onTap: () {},')"
mutate "selected tab not revealed on build" $TAB "s.replace('_reveal(Duration.zero);', '')"
mutate "selected tab not revealed on change" $TAB "s.replace('_reveal(McMotion.normal);', '')"
mutate "reveal scrolls every ancestor" $TAB \
  "re.sub(r'_controller\.position\.ensureVisible\(\s*object,', 'Scrollable.ensureVisible(_keys[widget.currentIndex].currentContext!,', s)"
mutate "reveal on every parent rebuild" $TAB \
  "s.replace('if (widget.currentIndex != oldWidget.currentIndex) {', 'if (widget.currentIndex != oldWidget.currentIndex || widget.tabs.isNotEmpty) {')"
mutate "tab fills a tall parent (no max height, no height factor)" $TAB \
  "s.replace('maxHeight: McTabBar.height,', '').replace('heightFactor: 1,', '')"
mutate "divider not padded in (48 pt, not 49)" $TAB \
  "re.sub(r'child: Padding\(\s*padding: const EdgeInsets\.only\(bottom: McTabBar\.dividerHeight\),\s*child: LayoutBuilder', 'child: Padding(padding: EdgeInsets.zero, child: LayoutBuilder', s)"
mutate "tabs do not share the free width" $TAB \
  "s.replace('math.max(0.0, width - total) / children.length', '0.0')"
mutate "unbounded width scrolls (crash)" $TAB \
  "s.replace('constraints.hasBoundedWidth', '(constraints.hasBoundedWidth || constraints.maxWidth.isInfinite)')"
mutate "no Material ancestor of its own" $TAB \
  "re.sub(r'Material\(\s*type: MaterialType\.transparency,', 'Container(', s)"
mutate "high-contrast divider keeps alpha" $TAB \
  "s.replace('McA11y.highContrast(context)', '!McA11y.highContrast(context)')"
mutate "currentIndex upper bound unchecked" $TAB \
  "s.replace('currentIndex < tabs.length', 'currentIndex <= tabs.length')"
mutate "tab label scale uncapped" $TAB \
  "s.replace('.clamp(maxScaleFactor: McTabBar.labelMaxScale)', '')"
echo "overall: $([[ $rc == 0 ]] && echo 'all mutations killed' || echo 'SOME SURVIVED OR FAILED')"
exit $rc
