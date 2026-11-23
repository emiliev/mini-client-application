import 'package:bloc/bloc.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// Marks a bloc state that represents a failure. [McBloc] reports every
/// transition into such a state to monitoring (D-16).
abstract interface class McFailureState {
  Object get error;
  StackTrace? get stackTrace;
}

/// The base class of every bloc: one place that logs transitions and errors
/// to [Monitoring] (D-16). A plain base class, not a mixin, so the outline
/// cutoff holds (R15).
abstract base class McBloc<Event, State> extends Bloc<Event, State> {
  McBloc(super.initialState, {required Monitoring monitoring})
    : _monitoring = monitoring;

  final Monitoring _monitoring;

  @override
  void onTransition(Transition<Event, State> transition) {
    super.onTransition(transition);
    final next = transition.nextState;
    if (next is McFailureState) {
      _monitoring.recordError(next.error, next.stackTrace);
    }
    _monitoring.log(
      '$runtimeType: ${transition.event.runtimeType} '
      '${transition.currentState.runtimeType} -> '
      '${next.runtimeType}',
      level: LogLevel.debug,
    );
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    _monitoring.recordError(error, stackTrace);
    super.onError(error, stackTrace);
  }
}
