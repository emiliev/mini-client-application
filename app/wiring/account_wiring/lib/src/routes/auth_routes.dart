import 'package:account_wiring/src/routes/route_targets.dart';
import 'package:app_core/app_core.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';

part 'auth_routes.g.dart';

/// The account group's auth routes (generated `$appRoutes`).
List<RouteBase> get authRoutes => $appRoutes;

/// `/auth/sign-in?from=<location>&reason=<code>`: the sign-in form (T-0066).
///
/// **A route that ends with a result** (plan 01 §4.3): a feature that needs a
/// session pushes it with `AppFlows.signIn` (`requestAppSignIn`) and awaits
/// whether someone signed in.
///
/// **The guard's route:** the router's guard sends a signed-out user who
/// opens a protected location here with `from` set to where they were going.
/// After the sign-in the route **goes to `from`** (`go`, which replaces this
/// page, so the stack stays `[home, target]`), if `from` is a location of
/// this app (`safeSignInTarget`: nothing else can be reached through it).
/// "Not now" completes as false: the route pops, so the user ends where they
/// came from, which is home for a cold link.
///
/// The result is a `bool` so that a guarded push of another result route
/// (`AppFlows.createReadingList` while signed out) never mistakes it for its
/// own `String` result (`AppFlows.signIn`).
///
/// The app shell nests it under home (T-0049).
@TypedGoRoute<SignInRoute>(path: '/auth/sign-in', name: 'auth_sign_in')
class SignInRoute extends GoRouteData with $SignInRoute {
  const SignInRoute({this.from, this.reason});

  /// Where the user was going when the guard sent them here.
  final String? from;

  /// What signing in is for: a `SignInPurpose` name, or nothing.
  final String? reason;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final router = GoRouter.of(context);
    return FlowResultRoute<bool>(
      extra: state.extra,
      builder: (complete) => diContainer<AccountRouteTargets>().signIn(
        reason: reason,
        onComplete: (signedIn) {
          if (signedIn && from != null) {
            router.go(safeSignInTarget(from));
          } else {
            complete(signedIn);
          }
        },
      ),
    );
  }
}
