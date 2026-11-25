import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';

/// Shared by the T-0035 navigation-channel tests: a recording router, a
/// sender that goes through the framework's real messenger path, and the
/// script whose replies the framework itself gives.

/// Records what the router receives from the framework. [popHandles] is what
/// its `popRoute` answers.
class RecordingDelegate extends RouterDelegate<Uri> with ChangeNotifier {
  RecordingDelegate(this.body, {this.popHandles = true});

  final ValueListenable<Widget> body;
  final bool popHandles;
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
    return popHandles;
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

Future<RecordingDelegate> mountRouter(
  WidgetTester tester,
  ValueNotifier<Widget> body, {
  bool popHandles = true,
}) async {
  final delegate = RecordingDelegate(body, popHandles: popHandles);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: McTheme.light,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerDelegate: delegate,
      routeInformationParser: _Parser(),
    ),
  );
  await tester.pumpAndSettle();
  // The initial route the router asks for at startup is not a link.
  delegate.locations.clear();
  return delegate;
}

/// Sends [method] the way the engine does (an inbound platform message on
/// `flutter/navigation`) and returns the decoded reply.
Future<Object?> sendNavigation(
  WidgetTester tester,
  String method, [
  Object? arguments,
]) async {
  Object? reply;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    const JSONMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
    (data) => reply = const JSONMethodCodec().decodeEnvelope(data!),
  );
  await tester.pump();
  return reply;
}

Future<Object?> sendLink(WidgetTester tester, String location) =>
    sendNavigation(tester, 'pushRouteInformation', {'location': location});

const String fullLink = '/a/b?q=1&r=x%20y#frag';

/// What the framework's own handler answers for [runScript], as recorded by
/// `framework_navigation_baseline_test.dart` on a binding where no
/// `FlowBuilder` has ever mounted. Replies are `[link, legacy pushRoute,
/// unknown method, popRoute the router handles]`.
const List<Object?> frameworkReplies = [true, true, false, true];
const List<String> frameworkLocations = [fullLink, '/legacy?z=2#f'];

/// The messages whose replies [frameworkReplies] lists. Returns the replies.
Future<List<Object?>> runScript(WidgetTester tester) async => [
  await sendLink(tester, fullLink),
  await sendNavigation(tester, 'pushRoute', '/legacy?z=2#f'),
  await sendNavigation(tester, 'nope'),
  await sendNavigation(tester, 'popRoute'),
];

List<String> asStrings(RecordingDelegate delegate) => [
  for (final uri in delegate.locations) uri.toString(),
];
