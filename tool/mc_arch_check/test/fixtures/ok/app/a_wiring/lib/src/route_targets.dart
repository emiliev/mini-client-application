import 'package:f_a/f_a.dart';

abstract class RouteTargets {
  static RouteTargets of(Object context) => throw 0;
  AFlow a({required int id});
  AFlow? maybe();
}

// Later code is not part of RouteTargets.
class Helper {
  Widget build() {
    Widget w = make();
    return w;
  }
}
