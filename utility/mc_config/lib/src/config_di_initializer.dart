import 'package:get_it/get_it.dart';
import 'package:mc_config/src/app_config.dart';
import 'package:mc_di/mc_di.dart';

/// Loads the text of `app_config.json`. The app passes a loader that reads
/// the bundled asset, so this package stays Flutter-free.
typedef ConfigSource = Future<String> Function();

/// Reads the config once and registers [AppConfig] as a singleton.
class ConfigDIInitializer extends McDIInitializer {
  ConfigDIInitializer(ConfigSource source) : super(_init(source));

  static GetItInitializer _init(ConfigSource source) =>
      (GetIt getIt, String? environment) async {
        getIt.registerSingleton<AppConfig>(AppConfig.parse(await source()));
      };
}
