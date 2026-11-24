import 'package:di_sample/src/clock.dart';
import 'package:injectable/injectable.dart';

/// Builds greetings. A new instance per resolve.
@injectable
class GreetingRepository {
  GreetingRepository(this._clock, @Named('appName') this._appName);

  final Clock _clock;
  final String _appName;

  String greeting(String name) => 'Hello $name from $_appName at ${_hour()}';

  int _hour() => _clock.now().hour;
}
