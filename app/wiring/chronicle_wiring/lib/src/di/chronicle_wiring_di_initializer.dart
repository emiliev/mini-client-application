import 'dart:async';
import 'dart:math';

import 'package:chronicle_wiring/src/di/di_initializer.dart';
import 'package:chronicle_wiring/src/routes/route_targets.dart';
import 'package:chronicle_wiring/src/routes/route_targets_impl.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:trivia_quiz/trivia_quiz.dart';

/// The chronicle group's root registrations: the navigator implementations
/// (injectable) and the route targets the typed routes resolve (by hand,
/// R15). Needs `RouterDIInitializer`, the session and api auth before it in
/// the root list; a navigator reaches the router only when first used.
class ChronicleWiringDIInitializer extends McDIInitializer {
  const ChronicleWiringDIInitializer() : super(_init);

  static FutureOr<void> _init(GetIt getIt, String? environment) async {
    await const ChronicleNavigatorsDIInitializer().init(getIt);
    getIt.registerLazySingleton<ChronicleRouteTargets>(
      () => ChronicleRouteTargetsImpl(
        trivia: getIt<TriviaQuizNavigator>(),
        clock: chronicleClock,
        nextSeed: chronicleSeed,
      ),
    );
  }
}

final Stopwatch _monotonic = Stopwatch()..start();

/// The quiz's countdown time (ADR-0014): monotonic milliseconds from a
/// `Stopwatch`, so a change of the device's wall clock cannot add or take
/// time from a question.
int chronicleClock() => _monotonic.elapsedMilliseconds;

final Random _random = Random();

/// A new round seed, uniform over the contract's range (0 to 2^31 - 1).
int chronicleSeed() => _random.nextInt(1 << 31);
