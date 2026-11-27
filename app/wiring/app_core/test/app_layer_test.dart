// T-0048-AC8: app_core's small app-layer pieces that no test of this package
// exercised before (they were only used by the app's and the sandbox's own
// tests): the route probe, the sandbox stub page, the media scope builder,
// the locations, and the app's mock domains (T-0048 adds the library).
import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_fixtures_editorial/mc_fixtures_editorial.dart';
import 'package:mc_fixtures_library/mc_fixtures_library.dart';

/// Records [route] and a redirect from inside [probe]'s scope.
class _Recorder extends StatelessWidget {
  const _Recorder(this.route);

  final String route;

  @override
  Widget build(BuildContext context) {
    McRouteProbe.record(context, route);
    McRouteProbe.recordRedirect(context, Uri.parse('/$route'));
    return const SizedBox.shrink();
  }
}

void main() {
  testWidgets('T-0048-AC8 the route probe counts builds and redirects, and '
      'those before ready', (tester) async {
    final probe = McRouteProbe();
    await tester.pumpWidget(
      McRouteProbeScope(probe: probe, child: const _Recorder('early')),
    );
    expect(probe.isReady, isFalse);
    probe.markReady();
    await tester.pumpWidget(
      McRouteProbeScope(probe: probe, child: const _Recorder('late')),
    );

    expect(probe.isReady, isTrue);
    expect(probe.builds, ['early', 'late']);
    expect(probe.redirects, ['/early', '/late']);
    expect(probe.beforeReady, 2, reason: 'one build and one redirect');
  });

  testWidgets('T-0048-AC8 without a probe, recording does nothing', (
    tester,
  ) async {
    await tester.pumpWidget(const _Recorder('none'));
    expect(tester.takeException(), isNull);
  });

  test('T-0048-AC8 the probe scope notifies only for another probe', () {
    final probe = McRouteProbe();
    final scope = McRouteProbeScope(probe: probe, child: const SizedBox());
    expect(
      scope.updateShouldNotify(
        McRouteProbeScope(probe: probe, child: const SizedBox()),
      ),
      isFalse,
    );
    expect(
      scope.updateShouldNotify(
        McRouteProbeScope(probe: McRouteProbe(), child: const SizedBox()),
      ),
      isTrue,
    );
  });

  testWidgets('T-0048-AC8 the sandbox stub names the location it does not '
      'host', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SandboxStubPage(location: '/comics/7')),
    );
    expect(find.byKey(const Key('sandbox.stub')), findsOneWidget);
    expect(find.text('/comics/7 is not part of this sandbox.'), findsOneWidget);
  });

  testWidgets('T-0048-AC8 the media scope builder wraps the app, or nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => mediaScopeBuilder(
          context,
          const Text('app', textDirection: TextDirection.ltr),
        ),
      ),
    );
    expect(find.byType(McMediaScope), findsOneWidget);
    expect(find.text('app'), findsOneWidget);

    await tester.pumpWidget(
      Builder(builder: (context) => mediaScopeBuilder(context, null)),
    );
    expect(find.byType(McMediaScope), findsOneWidget);
    expect(find.byType(SizedBox), findsOneWidget);
  });

  test('T-0048-AC8 the cross-group locations', () {
    expect(AppLocations.home, '/');
    expect(AppLocations.placeholder(7), '/placeholder/7');
    expect(AppLocations.characters, '/characters');
    expect(AppLocations.character(100366), '/characters/100366');
    expect(AppLocations.comic(501500), '/comics/501500');
  });

  test('T-0048-AC5 the app serves the library domain', () {
    expect(appMockDomains.whereType<LibraryMockDomain>(), hasLength(1));
  });

  test('T-0060-AC5 the app serves the trivia domain', () {
    expect(appMockDomains.whereType<TriviaMockDomain>(), hasLength(1));
  });
}
