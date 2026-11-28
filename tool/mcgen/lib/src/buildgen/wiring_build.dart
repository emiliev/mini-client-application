// The BUILD.bazel of a wiring group `mcgen wire` generates (T-0074).

import 'package:mcgen/src/buildgen/starlark.dart';

class WiringPackage {
  WiringPackage._(this.name, this.dir);

  factory WiringPackage.read(String name, String dir) =>
      WiringPackage._(name, dir);

  final String name;
  final String dir;
}

String wiringBuild(
  WiringPackage pkg,
  BuildFile? existing, {
  required String Function(String package) label,
  required String header,
}) => throw UnimplementedError('wiring BUILD');
