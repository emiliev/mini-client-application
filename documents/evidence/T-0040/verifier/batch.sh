#!/bin/bash
# T-0040 Verifier: my own mutations (each restored by mut.sh).
S=/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/T-0040-verifier
cd /Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-adeb065bbdc8df91c
L=utility/mc_ds_navigation/lib/src
T="//utility/mc_ds_navigation:navigation_test //utility/mc_ds_navigation:golden_test"
m() { "$S/mut.sh" "$@" $T; echo "-----"; }
m "V1 initState reveal removed" $L/mc_tab_bar.dart "_reveal(Duration.zero);" ""
m "V2 didUpdateWidget reveal removed" $L/mc_tab_bar.dart "_reveal(McMotion.normal);" ""
m "V3 reveal condition inverted" $L/mc_tab_bar.dart "widget.selected && !oldWidget.selected" "widget.selected && oldWidget.selected"
m "V4 controlled index ignored (always 0)" $L/mc_tab_bar.dart "selected: i == currentIndex," "selected: i == 0,"
m "V5 onChanged reports currentIndex" $L/mc_tab_bar.dart "onTap: () => onChanged(i)," "onTap: () => onChanged(currentIndex),"
m "V6 section action not wired" $L/mc_section_header.dart "onPressed: onAction," "onPressed: () {},"
m "V7 section action fires twice" $L/mc_section_header.dart "onPressed: onAction," "onPressed: () { onAction?.call(); onAction?.call(); },"
m "V8 section header minHeight dropped" $L/mc_section_header.dart "constraints: const BoxConstraints(minHeight: mcMinTapTarget)," "constraints: const BoxConstraints(),"
m "V9 tabBar role dropped" $L/mc_tab_bar.dart "role: SemanticsRole.tabBar," ""
m "V10 tab semantics onTap dropped" $L/mc_tab_bar.dart "      onTap: widget.onTap,
      excludeSemantics" "      excludeSemantics"
m "V11 tab button flag dropped" $L/mc_tab_bar.dart "button: true,
      label" "label"
m "V12 tab semantics label wrong" $L/mc_tab_bar.dart "label: widget.label," "label: 'tab',"
m "V13 centerTitle false" $L/mc_app_bar.dart "centerTitle: true," "centerTitle: false,"
m "V14 titleTextStyle dropped" $L/mc_app_bar.dart "titleTextStyle: McTypeScale.headline.copyWith(color: p.onSurface)," ""
m "V15 plain title overflow visible" $L/mc_app_bar.dart "overflow: TextOverflow.ellipsis,
            ),
      bottom:" "overflow: TextOverflow.visible,
            ),
      bottom:"
m "V16 large title style display->title" $L/mc_app_bar.dart "McTypeScale.display" "McTypeScale.title"
m "V17 tab selected colour = muted" $L/mc_tab_bar.dart "color: widget.selected ? p.primary : p.onSurfaceMuted," "color: p.onSurfaceMuted,"
m "V18 tab underline never drawn" $L/mc_tab_bar.dart "color: widget.selected ? p.primary : Colors.transparent," "color: Colors.transparent,"
m "V19 tab excludeSemantics false" $L/mc_tab_bar.dart "excludeSemantics: true," "excludeSemantics: false,"
m "V20 null leading becomes empty box" $L/mc_app_bar.dart "leading: leading," "leading: leading ?? const SizedBox.shrink(),"
m "V21 no automatic leading" $L/mc_app_bar.dart "leading: leading," "leading: leading, automaticallyImplyLeading: false,"
m "V22 large title not single-line" $L/mc_app_bar.dart "maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler" "textScaler"
