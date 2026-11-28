// `mcgen wire [--check]` (plan 02 section 2.8, T-0074).

import 'package:mcgen/src/core/format.dart';
import 'package:mcgen/src/core/spec/spec.dart';

int runWire(
  String root,
  List<ModuleSpec> specs,
  DartFormatter formatter, {
  required bool check,
  required StringSink out,
  required StringSink err,
}) {
  err.writeln('mcgen wire: not yet');
  return 3;
}
