import 'package:auth_signin/auth_signin.dart';
import 'package:injectable/injectable.dart';

/// auth_signin's way out of the feature. The form has no outbound intents
/// yet (sign-up and password reset would add them): it ends with a result,
/// which the route hands on (`SignInRoute`).
@LazySingleton(as: AuthSignInNavigator)
class AuthSignInNavigatorImpl implements AuthSignInNavigator {
  const AuthSignInNavigatorImpl();
}
