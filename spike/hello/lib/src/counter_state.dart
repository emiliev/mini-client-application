// Tide-shaped freezed union: `sealed`, private cases, consumed with
// `state.when` (R16, T-0014-AC6). Flutter-free on purpose (CPR, KD6), so the
// freezed codegen action can run on analyzer summaries.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'counter_state.freezed.dart';

@freezed
sealed class CounterState with _$CounterState {
  const factory CounterState.initial() = _Initial;
  const factory CounterState.counting(int count) = _Counting;
  const factory CounterState.failed({required String reason}) = _Failed;
}

/// Pure transition used by the widget: increments, or starts counting.
CounterState increment(CounterState state) => state.maybeWhen(
  counting: (count) => CounterState.counting(count + 1),
  orElse: () => const CounterState.counting(1),
);

/// A `map` call, so AC6 also proves `map` exists on the generated mixin.
String kindOf(CounterState state) => state.map(
  initial: (_) => 'initial',
  counting: (_) => 'counting',
  failed: (_) => 'failed',
);
