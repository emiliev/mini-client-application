import 'package:di_sample/src/greeting_repository.dart';
import 'package:di_sample/src/sample_module.dart';
import 'package:injectable/injectable.dart';

/// One greeter for the whole app.
@singleton
class Greeter {
  Greeter(this._repository, this._settings);

  final GreetingRepository _repository;
  final SampleSettings _settings;

  int get retries => _settings.retries;

  String greet(String name) => _repository.greeting(name);

  @disposeMethod
  void dispose() {}
}
