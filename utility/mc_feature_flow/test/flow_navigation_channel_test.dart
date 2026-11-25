import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';

/// T-0035: a mounted `FeatureFlow` (flow_builder) must leave Flutter's
/// `flutter/navigation` channel working: deep links reach the router, and the
/// framework's `popRoute` still works once the flow is gone.

class _State {
  const _State({this.pushed = false});
  final bool pushed;
}

/// Records what the router receives from the framework.
class _Delegate extends RouterDelegate<Uri> with ChangeNotifier {
  _Delegate(this.body);

  final ValueListenable<Widget> body;
  final List<Uri> locations = [];
  int pops = 0;

  @override
  Uri? get currentConfiguration => locations.isEmpty ? null : locations.last;

  @override
  Future<void> setNewRoutePath(Uri configuration) async {
    locations.add(configuration);
  }

  @override
  Future<bool> popRoute() async {
    pops++;
    return false;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Widget>(
    valueListenable: body,
    builder: (context, child, _) => Scaffold(body: child),
  );
}

class _Parser extends RouteInformationParser<Uri> {
  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) async =>
      routeInformation.uri;

  @override
  RouteInformation? restoreRouteInformation(Uri configuration) =>
      RouteInformation(uri: configuration);
}

Widget _flow({Widget? nested, bool startPushed = false}) => FeatureFlow<_State>(
  state: _State(pushed: startPushed),
  onGeneratePages: (state) => [
    McFlowPage(name: 'root', child: nested ?? const Text('flow root')),
    if (state.pushed) const McFlowPage(name: 'detail', child: Text('detail')),
  ],
);

/// Sends [method] the way the engine does: through the messenger, as an
/// inbound platform message on `flutter/navigation`.
Future<void> _send(
  WidgetTester tester,
  String method, [
  Object? arguments,
]) async {
  final data = const JSONMethodCodec().encodeMethodCall(
    MethodCall(method, arguments),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    data,
    (_) {},
  );
  await tester.pump();
}

Future<void> _link(WidgetTester tester, String location) =>
    _send(tester, 'pushRouteInformation', {'location': location});

Future<_Delegate> _mount(
  WidgetTester tester,
  ValueNotifier<Widget> body,
) async {
  final delegate = _Delegate(body);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: McTheme.light,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerDelegate: delegate,
      routeInformationParser: _Parser(),
    ),
  );
  await tester.pumpAndSettle();
  return delegate;
}

void main() {
  setUp(() async {
    await resetDIContainer();
    await initializeDIContainer(const []);
  });

  tearDown(resetDIContainer);

  testWidgets('T-0035-AC1 a deep link reaches the router while a '
      'FeatureFlow is mounted', (tester) async {
    final body = ValueNotifier<Widget>(const SizedBox());
    final delegate = await _mount(tester, body);

    // Control: the framework delivers links before any flow exists.
    await _link(tester, '/before');
    expect(delegate.locations.last.path, '/before');

    body.value = _flow();
    await tester.pumpAndSettle();
    expect(find.text('flow root'), findsOneWidget);

    await _link(tester, '/while-mounted?id=7');
    expect(delegate.locations.last.toString(), '/while-mounted?id=7');
  });

  testWidgets('T-0035-AC1 the legacy pushRoute message also reaches the '
      'router while a flow is mounted', (tester) async {
    final body = ValueNotifier<Widget>(_flow());
    final delegate = await _mount(tester, body);

    await _send(tester, 'pushRoute', '/legacy');
    expect(delegate.locations.last.path, '/legacy');
  });

  testWidgets('T-0035-AC2 after the flow is disposed, links and popRoute '
      'behave as without a flow', (tester) async {
    final body = ValueNotifier<Widget>(_flow());
    final delegate = await _mount(tester, body);
    await _link(tester, '/during');
    expect(delegate.locations.last.path, '/during');

    body.value = const SizedBox();
    await tester.pumpAndSettle();
    expect(find.text('flow root'), findsNothing);

    await _link(tester, '/after');
    expect(delegate.locations.last.path, '/after');
    final popsBefore = delegate.pops;
    await _send(tester, 'popRoute');
    expect(delegate.pops, popsBefore + 1);
  });

  testWidgets('T-0035-AC2 a flow nested inside another flow keeps links and '
      'popRoute working', (tester) async {
    final body = ValueNotifier<Widget>(
      _flow(nested: _flow(startPushed: true)),
    );
    final delegate = await _mount(tester, body);
    expect(find.text('detail'), findsOneWidget);

    await _link(tester, '/nested');
    expect(delegate.locations.last.path, '/nested');

    // The innermost flow takes the first popRoute (its pushed page goes), so
    // the router does not see it.
    await _send(tester, 'popRoute');
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsNothing);
    expect(delegate.pops, 0);

    // Unmounting everything leaves the channel working.
    body.value = const SizedBox();
    await tester.pumpAndSettle();
    await _link(tester, '/nested-after');
    expect(delegate.locations.last.path, '/nested-after');
    await _send(tester, 'popRoute');
    expect(delegate.pops, 1);
  });

  testWidgets('T-0035-AC2 popRoute pops a pushed flow page before the '
      'router sees it, and falls through at the flow root', (tester) async {
    final body = ValueNotifier<Widget>(_flow(startPushed: true));
    final delegate = await _mount(tester, body);
    expect(find.text('detail'), findsOneWidget);

    await _send(tester, 'popRoute');
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsNothing);
    expect(delegate.pops, 0);

    await _send(tester, 'popRoute');
    expect(delegate.pops, 1);
  });

  testWidgets('T-0035-AC2 an unknown navigation method is answered like the '
      'framework does (false)', (tester) async {
    final body = ValueNotifier<Widget>(_flow());
    await _mount(tester, body);

    Object? reply;
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      const JSONMethodCodec().encodeMethodCall(const MethodCall('nope')),
      (data) => reply = const JSONMethodCodec().decodeEnvelope(data!),
    );
    expect(reply, false);
  });
}
