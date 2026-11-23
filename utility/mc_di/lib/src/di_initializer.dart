import 'dart:async';

import 'package:get_it/get_it.dart';

/// Registers a package's types in [getIt]. Shape of injectable's generated
/// `init` function.
typedef GetItInitializer = FutureOr<void> Function(
  GetIt getIt,
  String? environment,
);

/// One per package that registers anything (Tide's `TideDIInitializer`).
class McDIInitializer {
  const McDIInitializer(this._initializer);

  final GetItInitializer _initializer;

  /// Runs the registrations against [getIt]. The environment is always null.
  FutureOr<void> init(GetIt getIt) => _initializer(getIt, null);
}
