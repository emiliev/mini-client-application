import 'package:mc_di/mc_di.dart';
import 'package:test/test.dart';

class _A {}

class _B {
  _B(this.a);
  final _A a;
}

void main() {
  setUp(resetDIContainer);

  test(
    'T-0022-AC6 debugResolveAll passes when every dependency exists',
    () async {
      final child = await createChildContainer(
        initializers: [
          McDIInitializer((getIt, _) {
            getIt
              ..registerLazySingleton<_A>(_A.new)
              ..registerFactory<_B>(() => _B(getIt<_A>()));
          }),
        ],
      );
      await child.debugResolveAll();
      expect(child<_B>().a, isNotNull);
    },
  );

  test(
    'T-0022-AC6 debugResolveAll names the type and its missing dependency',
    () async {
      final child = await createChildContainer(
        initializers: [
          McDIInitializer(
            (getIt, _) => getIt.registerFactory<_B>(() => _B(getIt<_A>())),
          ),
        ],
      );
      await expectLater(
        child.debugResolveAll(),
        throwsA(
          isA<StateError>().having(
            (e) => '$e',
            'message',
            allOf(contains('_B'), contains('_A')),
          ),
        ),
      );
    },
  );
}
