import 'package:injectable/injectable.dart';

/// The time source the sample's services read.
abstract class Clock {
  DateTime now();
}

/// The production [Clock]. Registered as a lazy singleton under [Clock].
@LazySingleton(as: Clock)
class SystemClock implements Clock {
  @override
  DateTime now() => DateTime.now();
}
