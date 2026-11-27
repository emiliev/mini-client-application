// The archetype registry. P2-04 to P2-07 each add one line here (and own
// lib/src/emit/<archetype>/ and bricks/<archetype>*).

import 'package:mcgen/src/core/archetype.dart';
import 'package:mcgen/src/emit/utility_hello/utility_hello.dart';

const Map<String, Archetype> archetypes = {
  'utility_hello': UtilityHelloArchetype(),
};
