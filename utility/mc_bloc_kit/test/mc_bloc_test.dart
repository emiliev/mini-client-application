import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:test/test.dart';

sealed class _State {
  const _State();
}

class _Idle extends _State {
  const _Idle();
}

class _Busy extends _State {
  const _Busy();
}

class _Failed extends _State implements McFailureState {
  const _Failed(this.error, this.stackTrace);

  @override
  final Object error;
  @override
  final StackTrace? stackTrace;
}

final class _Counter extends McBloc<String, _State> {
  _Counter(Monitoring monitoring)
    : super(const _Idle(), monitoring: monitoring) {
    on<String>((event, emit) {
      if (event == 'fail') {
        emit(_Failed(StateError('boom'), StackTrace.empty));
      } else if (event == 'throw') {
        addError(StateError('handler'), StackTrace.empty);
      } else {
        emit(const _Busy());
      }
    });
  }
}

void main() {
  late InMemorySink sink;
  late _Counter bloc;

  setUp(() {
    sink = InMemorySink();
    bloc = _Counter(Monitoring([sink]));
  });

  tearDown(() => bloc.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('T-0022-AC7 a transition is logged once through monitoring', () async {
    bloc.add('go');
    await settle();
    final logs = sink.entries.whereType<LogEntry>().toList();
    expect(logs, hasLength(1));
    expect(logs.single.message, contains('_Counter'));
    expect(logs.single.level, LogLevel.debug);
    expect(sink.entries.whereType<ErrorEntry>(), isEmpty);
  });

  test('T-0022-AC7 a McFailureState transition records its error', () async {
    bloc.add('fail');
    await settle();
    final errors = sink.entries.whereType<ErrorEntry>().toList();
    expect(errors, hasLength(1));
    expect(errors.single.error, isA<StateError>());
  });

  test('T-0022-AC7 an error added to the bloc is recorded', () async {
    bloc.add('throw');
    await settle();
    final errors = sink.entries.whereType<ErrorEntry>().toList();
    expect(errors, hasLength(1));
    expect(errors.single.error, isA<StateError>());
  });
}
