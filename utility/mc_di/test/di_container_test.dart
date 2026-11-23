import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:test/test.dart';

class Foo {}

class Bar {}

class Baz {
  Baz(this.foo);

  final Foo foo;
}

class Counted {
  Counted(this.id);

  final int id;
}

void main() {
  setUp(resetDIContainer);

  group('T-0017-AC6 initializeDIContainer', () {
    test('T-0017-AC6 runs initializers in order and resolves both', () async {
      final order = <String>[];
      final first = McDIInitializer((GetIt g, String? env) {
        order.add('first');
        g.registerSingleton<Foo>(Foo());
      });
      final second = McDIInitializer((GetIt g, String? env) async {
        await Future<void>.delayed(Duration.zero);
        order.add('second');
        g.registerSingleton<Bar>(Bar());
      });

      final sut = await initializeDIContainer(<McDIInitializer>[first, second]);

      expect(order, <String>['first', 'second']);
      expect(sut<Foo>(), isA<Foo>());
      expect(diContainer<Bar>(), isA<Bar>());
      expect(sut.isRegistered<Foo>(), isTrue);
      expect(sut.isRegistered<Baz>(), isFalse);
    });

    test('T-0017-AC6 passes the factory parameter and the name', () async {
      await initializeDIContainer(<McDIInitializer>[
        McDIInitializer((GetIt g, String? env) {
          g.registerFactoryParam<Counted, int, void>(
            (int id, _) => Counted(id),
          );
          g.registerSingleton<Foo>(Foo(), instanceName: 'named');
        }),
      ]);

      expect(diContainer<Counted>(parameter: 7).id, 7);
      expect(diContainer.isRegistered<Foo>(name: 'named'), isTrue);
      expect(diContainer.isRegistered<Foo>(), isFalse);
      expect(diContainer<Foo>(name: 'named'), isA<Foo>());
    });

    test('T-0017-AC6 a throwing second initializer publishes nothing, '
        'and a retry registers each type exactly once', () async {
      var registrations = 0;
      var shouldThrow = true;
      final first = McDIInitializer((GetIt g, String? env) {
        registrations++;
        g.registerSingleton<Foo>(Foo());
      });
      final second = McDIInitializer((GetIt g, String? env) {
        if (shouldThrow) {
          throw StateError('second failed');
        }
        g.registerSingleton<Bar>(Bar());
      });

      await expectLater(
        initializeDIContainer(<McDIInitializer>[first, second]),
        throwsA(isA<StateError>()),
      );

      expect(diContainer.isRegistered<Foo>(), isFalse);
      expect(diContainer.isRegistered<Bar>(), isFalse);

      shouldThrow = false;
      await initializeDIContainer(<McDIInitializer>[first, second]);

      expect(registrations, 2);
      expect(diContainer<Foo>(), isA<Foo>());
      expect(diContainer<Bar>(), isA<Bar>());
    });

    test('T-0017-AC6 a failed init disposes what it had created', () async {
      var disposed = false;
      final first = McDIInitializer((GetIt g, String? env) {
        g.registerSingleton<Foo>(Foo(), dispose: (Foo _) => disposed = true);
      });
      final second = McDIInitializer((GetIt g, String? env) {
        throw StateError('second failed');
      });

      await expectLater(
        initializeDIContainer(<McDIInitializer>[first, second]),
        throwsA(isA<StateError>()),
      );

      expect(disposed, isTrue);
    });

    test(
      'T-0017-AC7 production init never resets: a second init throws',
      () async {
        final initializer = McDIInitializer(
          (GetIt g, String? env) => g.registerSingleton<Foo>(Foo()),
        );
        await initializeDIContainer(<McDIInitializer>[initializer]);

        await expectLater(
          initializeDIContainer(<McDIInitializer>[initializer]),
          throwsA(isA<StateError>()),
        );

        expect(diContainer<Foo>(), isA<Foo>());
      },
    );
  });

  group('T-0017-AC7 child containers', () {
    test('T-0017-AC7 RootImport<Foo> resolves to the root singleton, '
        'child-only types are invisible at the root', () async {
      final foo = Foo();
      await initializeDIContainer(<McDIInitializer>[
        McDIInitializer(
          (GetIt g, String? env) => g.registerSingleton<Foo>(foo),
        ),
      ]);

      final sut = await createChildContainer(
        rootImports: const <RootImport<Object>>[RootImport<Foo>()],
        initializers: <McDIInitializer>[
          McDIInitializer(
            (GetIt g, String? env) =>
                g.registerFactory<Baz>(() => Baz(g<Foo>())),
          ),
        ],
      );

      expect(sut<Foo>(), same(foo));
      expect(sut<Baz>().foo, same(foo));
      expect(sut.isRegistered<Baz>(), isTrue);
      expect(diContainer.isRegistered<Baz>(), isFalse);
      expect(() => diContainer<Baz>(), throwsA(anything));
    });

    test(
      'T-0017-AC7 a named RootImport forwards the named registration',
      () async {
        final foo = Foo();
        await initializeDIContainer(<McDIInitializer>[
          McDIInitializer(
            (GetIt g, String? env) =>
                g.registerSingleton<Foo>(foo, instanceName: 'n'),
          ),
        ]);

        final sut = await createChildContainer(
          rootImports: const <RootImport<Object>>[RootImport<Foo>(name: 'n')],
        );

        expect(sut<Foo>(name: 'n'), same(foo));
        expect(sut.isRegistered<Foo>(), isFalse);
      },
    );

    test(
      'T-0017-AC7 a RootImport without a root registration fails naming T',
      () async {
        await initializeDIContainer(<McDIInitializer>[]);

        await expectLater(
          createChildContainer(
            rootImports: const <RootImport<Object>>[RootImport<Foo>()],
          ),
          throwsA(
            isA<StateError>().having(
              (StateError e) => e.message,
              'message',
              contains('RootImport<Foo>'),
            ),
          ),
        );
      },
    );

    test('T-0017-AC7 disposing a child leaves the root alone', () async {
      await initializeDIContainer(<McDIInitializer>[
        McDIInitializer(
          (GetIt g, String? env) => g.registerSingleton<Foo>(Foo()),
        ),
      ]);
      final sut = await createChildContainer(
        rootImports: const <RootImport<Object>>[RootImport<Foo>()],
      );

      await sut.dispose();

      expect(sut.isRegistered<Foo>(), isFalse);
      expect(diContainer.isRegistered<Foo>(), isTrue);
    });
  });

  group('T-0017-AC7 lifecycle', () {
    test('T-0017-AC7 a RootImport forwards factory parameters', () async {
      await initializeDIContainer(<McDIInitializer>[
        McDIInitializer(
          (GetIt g, String? env) => g.registerFactoryParam<Counted, int, void>(
            (int id, _) => Counted(id),
          ),
        ),
      ]);
      final sut = await createChildContainer(
        rootImports: const <RootImport<Object>>[RootImport<Counted>()],
      );

      expect(sut<Counted>(parameter: 7).id, 7);
    });

    test('T-0017-AC7 reset during an in-flight init throws and the init '
        'still publishes', () async {
      final gate = Completer<void>();
      final init = initializeDIContainer(<McDIInitializer>[
        McDIInitializer((GetIt g, String? env) async {
          await gate.future;
          g.registerSingleton<Foo>(Foo());
        }),
      ]);

      await expectLater(resetDIContainer(), throwsA(isA<StateError>()));
      gate.complete();
      await init;

      expect(diContainer.isRegistered<Foo>(), isTrue);
    });

    test('T-0017-AC7 a child follows the root across a reset', () async {
      McDIInitializer initializer(Foo foo) => McDIInitializer(
        (GetIt g, String? env) => g.registerSingleton<Foo>(foo),
      );
      final first = Foo();
      final second = Foo();
      await initializeDIContainer(<McDIInitializer>[initializer(first)]);
      final sut = await createChildContainer(
        rootImports: const <RootImport<Object>>[RootImport<Foo>()],
      );
      expect(sut<Foo>(), same(first));

      await resetDIContainer();
      await initializeDIContainer(<McDIInitializer>[initializer(second)]);

      expect(sut<Foo>(), same(second));
    });
  });

  group('T-0017-AC7 resetDIContainer', () {
    var seenBefore = true;

    test('T-0017-AC7 first test registers a singleton', () async {
      expect(diContainer.isRegistered<Foo>(), isFalse);
      await initializeDIContainer(<McDIInitializer>[
        McDIInitializer(
          (GetIt g, String? env) => g.registerSingleton<Foo>(Foo()),
        ),
      ]);
      seenBefore = diContainer.isRegistered<Foo>();
      expect(seenBefore, isTrue);
    });

    test('T-0017-AC7 reset in setUp isolates the second test', () async {
      expect(seenBefore, isTrue, reason: 'ran after the first test');
      expect(diContainer.isRegistered<Foo>(), isFalse);

      // and the root can be initialised again, because reset cleared the guard.
      await initializeDIContainer(<McDIInitializer>[
        McDIInitializer(
          (GetIt g, String? env) => g.registerSingleton<Foo>(Foo()),
        ),
      ]);
      expect(diContainer.isRegistered<Foo>(), isTrue);
    });

    test('T-0017-AC7 reset disposes the singletons', () async {
      var disposed = false;
      await initializeDIContainer(<McDIInitializer>[
        McDIInitializer(
          (GetIt g, String? env) => g.registerSingleton<Foo>(
            Foo(),
            dispose: (Foo _) => disposed = true,
          ),
        ),
      ]);

      await resetDIContainer();

      expect(disposed, isTrue);
    });
  });
}
