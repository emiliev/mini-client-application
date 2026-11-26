import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_api_auth/src/auth_api.dart';
import 'package:mc_api_auth/src/auth_interceptor.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_session/mc_session.dart';

/// Registers [AuthApi] and puts the [AuthInterceptor] on the shared [Dio], so
/// every feature's calls carry the bearer. List `SessionDIInitializer` and
/// `ApiClientDIInitializer` first. The interceptor goes after the ones the
/// client already installed (logging, retry).
class ApiAuthDIInitializer extends McDIInitializer {
  const ApiAuthDIInitializer() : super(_init);

  static void _init(GetIt getIt, String? environment) {
    final dio = getIt<Dio>();
    final reader = getIt<SessionReader>();
    final writer = getIt<SessionWriter>();
    final api = AuthApi(dio, reader, writer);
    getIt.registerSingleton<AuthApi>(api);
    dio.interceptors.add(AuthInterceptor(dio, reader, writer, api));
  }
}
