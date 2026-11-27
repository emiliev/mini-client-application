// T-0049: the app shell re-roots each wiring's absolute routes under home.
import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRoute _route(String path, {List<RouteBase> routes = const []}) => GoRoute(
  path: path,
  name: path,
  builder: (context, state) => Text('page $path', key: Key(path)),
  routes: routes,
);

void main() {
  test('T-0049-AC1 entity routes become relative children of home, '
      'children kept', () {
    final routes = nestUnderHome(
      [
        _route('/', routes: [_route('placeholder/:id')]),
      ],
      [
        _route('/characters', routes: [_route(':id')]),
        _route('/comics/:id'),
      ],
    );

    expect(routes, hasLength(1), reason: 'nothing stays top level');
    final home = routes.single as GoRoute;
    expect(home.path, '/');
    expect(home.routes.cast<GoRoute>().map((r) => r.path), [
      'placeholder/:id',
      'characters',
      'comics/:id',
    ]);
    final characters = home.routes[1] as GoRoute;
    expect(characters.name, '/characters', reason: 'fields are kept');
    expect((characters.routes.single as GoRoute).path, ':id');
  });

  testWidgets('T-0049-AC1 a link to a nested route builds [home, target]', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/comics/7',
      routes: nestUnderHome([_route('/')], [_route('/comics/:id')]),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('/comics/:id')), findsOneWidget);
    expect(router.canPop(), isTrue, reason: 'home is below');

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('/')), findsOneWidget);
  });

  test('T-0049-AC1 a second route at exactly "/" is refused', () {
    expect(
      () => nestUnderHome([_route('/')], [_route('/')]),
      throwsStateError,
    );
  });

  test('T-0049-AC1 a relative entity route, a missing home and two homes '
      'are refused', () {
    expect(
      () => nestUnderHome([_route('/')], [_route('comics')]),
      throwsStateError,
    );
    expect(() => nestUnderHome([], [_route('/a')]), throwsStateError);
    expect(
      () => nestUnderHome([_route('/'), _route('/')], [_route('/a')]),
      throwsStateError,
    );
    expect(
      () => nestUnderHome(
        [_route('/')],
        [
          ShellRoute(builder: (_, _, child) => child, routes: [_route('/a')]),
        ],
      ),
      throwsStateError,
    );
  });
}
