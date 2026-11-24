import 'dart:async';

import 'package:get_it/get_it.dart';
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

  Matcher failsNaming(List<String> parts) => throwsA(
    isA<StateError>().having(
      (e) => '$e',
      'message',
      allOf([for (final p in parts) contains(p)]),
    ),
  );

  Future<ChildDIContainer> childWith(
    FutureOr<void> Function(GetIt getIt) body,
  ) => createChildContainer(
    initializers: [McDIInitializer((getIt, _) => body(getIt))],
  );

  test('T-0022-AC6 an unregistered type is no longer resolved', () async {
    final child = await childWith((getIt) {
      getIt
        ..registerFactory<_B>(() => _B(getIt<_A>()))
        ..unregister<_B>();
    });
    await child.debugResolveAll();
  });

  test('T-0022-AC6 reset forgets earlier registrations', () async {
    final child = await childWith((getIt) async {
      getIt.registerFactory<_B>(() => _B(getIt<_A>()));
      await getIt.reset();
      getIt.registerSingleton<_A>(_A());
    });
    await child.debugResolveAll();
  });

  test('T-0022-AC6 pushNewScope registrations are recorded', () async {
    final child = await childWith((getIt) {
      getIt.pushNewScope(
        init: (scoped) => scoped.registerFactory<_B>(() => _B(scoped<_A>())),
      );
    });
    await expectLater(child.debugResolveAll(), failsNaming(['_B', '_A']));
  });

  test('T-0022-AC6 popScope forgets the scope registrations', () async {
    final child = await childWith((getIt) async {
      await getIt.pushNewScopeAsync(
        init: (scoped) async =>
            scoped.registerFactory<_B>(() => _B(scoped<_A>())),
      );
      await getIt.popScope();
    });
    await child.debugResolveAll();
  });

  test('T-0022-AC6 dropScope forgets that scope only', () async {
    final child = await childWith((getIt) async {
      getIt
        ..pushNewScope(
          scopeName: 'one',
          init: (scoped) => scoped.registerFactory<_B>(() => _B(scoped<_A>())),
        )
        ..pushNewScope(
          scopeName: 'two',
          init: (scoped) => scoped.registerSingleton<_A>(_A()),
        );
      await getIt.dropScope('one');
    });
    await child.debugResolveAll();
  });

  test(
    'T-0022-AC6 a singleton that never signals ready names its type',
    () async {
      final child = await childWith(
        (getIt) => getIt.registerSingleton<_A>(_A(), signalsReady: true),
      );
      await expectLater(
        child.debugResolveAll(timeout: const Duration(milliseconds: 50)),
        failsNaming(['_A', 'not ready']),
      );
    },
  );

  test(
    'T-0022-AC6 a never-ready dependency names its type, not a hang',
    () async {
      final child = await childWith((getIt) {
        getIt
          ..registerSingletonAsync<_A>(() => Completer<_A>().future)
          ..registerSingletonWithDependencies<_B>(
            () => _B(getIt<_A>()),
            dependsOn: [_A],
          );
      });
      await expectLater(
        child.debugResolveAll(timeout: const Duration(milliseconds: 50)),
        failsNaming(['_A', 'not ready']),
      );
    },
  );

  test('T-0022-AC6 an async singleton is awaited, not failed', () async {
    final child = await childWith(
      (getIt) => getIt.registerSingletonAsync<_A>(() async => _A()),
    );
    await child.debugResolveAll();
  });
}
