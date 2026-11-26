import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_formatters/src/formatters.dart';

/// Loads the locale data the formatters need (`initializeFormatters`), once
/// per boot. It registers nothing. In the app's root list (plan 01 §3.4,
/// where `L10nCoreDIInitializer` sits) and in `McTestContainer`, so no
/// feature loads it itself (T-0041, F-0040 fact 1).
class FormattersDIInitializer extends McDIInitializer {
  const FormattersDIInitializer() : super(_init);

  static Future<void> _init(GetIt getIt, String? environment) =>
      initializeFormatters();
}
