import 'package:di_sample/di_sample.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:test/test.dart';

void main() {
  setUp(resetDIContainer);

  test('T-0028-AC1 the generated config registers all five annotated '
      'classes through McDIInitializer', () async {
    final container = await initializeDIContainer([diSampleDIInitializer]);

    expect(container<Clock>(), isA<SystemClock>());
    expect(container<Clock>(), same(container<Clock>()));
    expect(container<String>(name: 'appName'), 'mini-client');
    expect(container<SampleSettings>().retries, 3);
    expect(
      container<GreetingRepository>(),
      isNot(same(container<GreetingRepository>())),
    );
    expect(container<Greeter>(), same(container<Greeter>()));
    expect(container<Greeter>().greet('Ann'), startsWith('Hello Ann from mini-client'));
    expect(container<Badge>(parameter: 'new').render(), startsWith('[new '));
  });

  test('T-0028-AC4 a file whose shard is [] registers nothing', () async {
    final getIt = GetIt.asNewInstance();
    await diSampleDIInitializer.init(getIt);
    expect(getIt.isRegistered<PlainHelper>(), isFalse);
    expect(const PlainHelper().shout('a'), 'A');
  });
}
