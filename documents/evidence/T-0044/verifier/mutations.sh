#!/bin/bash
# T-0044 verifier mutations. Each: replace exactly one string, run both tests uncached, restore.
cd /Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-ad73251e8fb19c4ee || exit 1
L=utility/mc_ds_inputs/lib/src
LOG=/tmp/mc-T-0044-verifier-mut.log
: > $LOG
run() { # name file old new
  python3 -I - "$2" "$3" "$4" <<'E' || { echo "$1: PATTERN NOT FOUND" >> $LOG; return; }
import sys
f,o,n=sys.argv[1:4]
s=open(f).read()
assert s.count(o)==1,(s.count(o))
open(f,'w').write(s.replace(o,n))
E
  tool/bazelw --output_base=/tmp/mc-ob-T-0044-verifier test --nocache_test_results //utility/mc_ds_inputs:inputs_test //utility/mc_ds_inputs:golden_test --keep_going > /tmp/mc-T-0044-verifier-m.out 2>&1
  rc=$?
  failing=$(grep -E "^//utility.*FAILED" /tmp/mc-T-0044-verifier-m.out | tr -s ' ' | tr '\n' ' ')
  echo "$1: rc=$rc $failing" >> $LOG
  git checkout -- "$2"
  git diff --quiet || echo "!! dirty after $1" >> $LOG
}
run M1_layoutbuilder_back $L/field_style.dart 'Widget boundedFieldWidth(Widget field) => _BoundedFieldWidth(child: field);' 'Widget boundedFieldWidth(Widget field) => LayoutBuilder(builder: (c, k) => k.hasBoundedWidth ? field : SizedBox(width: mcFieldUnboundedWidth, child: field));'
run M2_chip_no_strip_tap $L/mc_chip.dart '          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onSelected!(!selected) : null,' '          behavior: HitTestBehavior.opaque,
          onTap: null,'
run M3_search_disabled_surface $L/mc_search_field.dart 'widget.enabled ? p.surfaceVariant : p.background' 'widget.enabled ? p.surfaceVariant : p.surface'
run M4_stepper_no_clamp_max $L/mc_stepper.dart 'v < min ? min : (v > max ? max : v)' 'v < min ? min : v'
run M5_stepper_inc_never_disabled $L/mc_stepper.dart 'change != null && value < max;' 'change != null;'
run M6_clear_always $L/mc_search_field.dart 'value.text.isEmpty || !widget.enabled' '!widget.enabled'
run M7_segment_selected_flag $L/mc_segmented.dart '      button: true,
      selected: selected,' '      button: true,
      selected: false,'
run M8_chip_multi_no_remove $L/mc_chip_group.dart '({..._multi!}..remove(value))' '{..._multi!, value}'
run M9_clear_no_onchanged $L/mc_search_field.dart "    widget.onChanged?.call('');
" ''
run M10_chip_min_tap $L/mc_chip.dart 'minHeight: mcMinTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: McSpacing.xs),' 'minHeight: 30,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: McSpacing.xs),'
echo done >> $LOG
