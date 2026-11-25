import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';

/// Holds the app's one `GoRouter`, which `McApp` only creates once boot is
/// ready (R29), so that a navigator implementation registered during boot
/// can still reach it later. `McApp` calls [attach]; [RouterDIInitializer]
/// registers [router] as a lazy `GoRouter`.
class RouterRef {
  GoRouter? _router;

  /// The attached router. Throws before `McApp` has created it.
  GoRouter get router =>
      _router ??
      (throw StateError(
        'The router does not exist yet: it is created when boot is ready, so '
        'a navigator may only be used from a route or a callback.',
      ));

  /// Records [router] and returns it.
  GoRouter attach(GoRouter router) => _router = router;

  /// Forgets the router (`McApp` disposes it), so a disposed `GoRouter` is
  /// never handed out. Safe to call more than once.
  void detach() => _router = null;
}

/// Registers `GoRouter` from [RouterRef] on every resolution (a factory, so
/// it never caches a router that was later detached), for navigator
/// implementations (`@LazySingleton` classes taking a `GoRouter`).
class RouterDIInitializer extends McDIInitializer {
  RouterDIInitializer(RouterRef ref) : super(_init(ref));

  static GetItInitializer _init(RouterRef ref) =>
      (GetIt getIt, String? environment) {
        getIt.registerFactory<GoRouter>(() => ref.router);
      };
}
