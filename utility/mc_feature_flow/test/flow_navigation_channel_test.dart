import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';

import 'navigation_channel_support.dart';

/// T-0035: a mounted `FeatureFlow` (flow_builder) must leave Flutter's
/// `flutter/navigation` channel working: deep links reach the router, and the
/// framework's replies are unchanged once the flow is gone. The framework's
/// own replies are constants from `framework_navigation_baseline_test.dart`,
/// so nothing here depends on test order.

class _State {
  const _State({this.pushed = false});
  final bool pushed;
}

Widget _flow({Widget? nested, bool startPushed = false}) => FeatureFlow<_State>(
  state: _State(pushed: startPushed),
  onGeneratePages: (state) => [
    McFlowPage(name: 'root', child: nested ?? const Text('flow root')),
    if (state.pushed) const McFlowPage(name: 'detail', child: Text('detail')),
  ],
);

void main() {
  setUp(() async {
    await resetDIContainer();
    await initializeDIContainer(const []);
  });

  tearDown(resetDIContainer);

  testWidgets('T-0035-AC1 a deep link reaches the router while a '
      'FeatureFlow is mounted, query and fragment intact, and is answered '
      'true', (tester) async {
    final body = ValueNotifier<Widget>(_flow());
    final delegate = await mountRouter(tester, body);
    expect(find.text('flow root'), findsOneWidget);

    expect(await sendLink(tester, fullLink), true);
    expect(delegate.locations.last.toString(), fullLink);
    expect(delegate.locations.last.fragment, 'frag');
    expect(delegate.locations.last.queryParameters, {'q': '1', 'r': 'x y'});

    // A second link straight after still arrives.
    expect(await sendLink(tester, '/second'), true);
    expect(delegate.locations.last.path, '/second');
  });

  testWidgets('T-0035-AC1 the legacy pushRoute message also reaches the '
      'router while a flow is mounted', (tester) async {
    final body = ValueNotifier<Widget>(_flow());
    final delegate = await mountRouter(tester, body);

    expect(await sendNavigation(tester, 'pushRoute', '/legacy'), true);
    expect(delegate.locations.last.path, '/legacy');
  });

  testWidgets('T-0035-AC2 after the flow is disposed, the replies equal the '
      "framework's own", (tester) async {
    final body = ValueNotifier<Widget>(_flow());
    final delegate = await mountRouter(tester, body);
    expect(await sendLink(tester, '/during'), true);

    body.value = const SizedBox();
    await tester.pumpAndSettle();
    expect(find.text('flow root'), findsNothing);
    delegate.locations.clear();

    expect(await runScript(tester), frameworkReplies);
    expect(asStrings(delegate), frameworkLocations);
    expect(delegate.pops, 1);
  });

  testWidgets('T-0035-AC2 a flow nested inside another flow keeps links and '
      'popRoute working', (tester) async {
    final body = ValueNotifier<Widget>(_flow(nested: _flow(startPushed: true)));
    final delegate = await mountRouter(tester, body);
    expect(find.text('detail'), findsOneWidget);

    expect(await sendLink(tester, '/nested'), true);
    expect(delegate.locations.last.path, '/nested');

    // The innermost flow takes the first popRoute (its pushed page goes), so
    // the router does not see it. It answers true: iOS counts any other reply
    // as unhandled.
    expect(await sendNavigation(tester, 'popRoute'), true);
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsNothing);
    expect(delegate.pops, 0);

    // Unmounting everything leaves the channel as the framework answers it.
    body.value = const SizedBox();
    await tester.pumpAndSettle();
    delegate.locations.clear();
    expect(await runScript(tester), frameworkReplies);
    expect(asStrings(delegate), frameworkLocations);
  });

  testWidgets('T-0035-AC2 popRoute pops a pushed flow page before the '
      'router sees it (answered true), and falls through at the flow root', (
    tester,
  ) async {
    final body = ValueNotifier<Widget>(_flow(startPushed: true));
    final delegate = await mountRouter(tester, body);
    expect(find.text('detail'), findsOneWidget);

    expect(await sendNavigation(tester, 'popRoute'), true);
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsNothing);
    expect(delegate.pops, 0);

    expect(await sendNavigation(tester, 'popRoute'), true);
    expect(delegate.pops, 1);
  });

  testWidgets('T-0035-AC2 an unknown navigation method is answered like the '
      'framework does (false) while a flow is mounted', (tester) async {
    final body = ValueNotifier<Widget>(_flow());
    await mountRouter(tester, body);

    expect(await sendNavigation(tester, 'nope'), false);
  });
}
