// The archetype registry. P2-04 to P2-07 each add one line here (and own
// lib/src/emit/<archetype>/ and bricks/<archetype>*).

import 'package:mcgen/src/core/archetype.dart';
import 'package:mcgen/src/emit/feature_dashboard/dashboard.dart';
import 'package:mcgen/src/emit/feature_list_detail/list_detail.dart';
import 'package:mcgen/src/emit/feature_search/search.dart';
import 'package:mcgen/src/emit/feature_section_detail/section_detail.dart';
import 'package:mcgen/src/emit/utility_hello/utility_hello.dart';

const Map<String, Archetype> archetypes = {
  'dashboard': DashboardArchetype(),
  'list_detail': ListDetailArchetype(),
  'search': SearchArchetype(),
  'section_detail': SectionDetailArchetype(),
  'utility_hello': UtilityHelloArchetype(),
};
