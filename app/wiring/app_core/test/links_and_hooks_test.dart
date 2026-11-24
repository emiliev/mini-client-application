import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

void main() {
  test('normalise keeps path, query and fragment of a miniclient link', () {
    expect(
      PendingLinks.normalise('miniclient://app/placeholder/7'),
      '/placeholder/7',
    );
    expect(
      PendingLinks.normalise('miniclient://app/placeholder/7?x=1#f'),
      '/placeholder/7?x=1#f',
    );
    expect(PendingLinks.normalise('miniclient://app'), '/');
    expect(PendingLinks.normalise('/placeholder/3'), '/placeholder/3');
  });

  testWidgets('while attached it consumes pushed links, newest wins', (
    tester,
  ) async {
    final links = PendingLinks.install(tester.binding);
    addTearDown(links.detach);
    expect(links.pending, isNull);

    final first = await tester.binding.handlePushRoute('/placeholder/1');
    await tester.binding.handlePushRoute('miniclient://app/placeholder/2');

    expect(first, isTrue, reason: 'consumed, so no other observer sees it');
    expect(links.received, 2);
    expect(links.take(), '/placeholder/2');
    expect(links.take(), '/', reason: 'take() clears the held link');
    expect(links.takes, 2);
  });

  testWidgets('the cold-start link is the platform default route', (
    tester,
  ) async {
    tester.platformDispatcher.defaultRouteNameTestValue = '/placeholder/9';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    final links = PendingLinks.install(tester.binding);
    addTearDown(links.detach);
    expect(links.pending, '/placeholder/9');
  });

  testWidgets('after detach it no longer consumes links', (tester) async {
    final links = PendingLinks.install(tester.binding)..detach();
    final probe = _Probe();
    tester.binding.addObserver(probe);
    addTearDown(() => tester.binding.removeObserver(probe));
    await tester.binding.handlePushRoute('/placeholder/4');
    expect(links.received, 0);
    expect(links.isAttached, isFalse);
    expect(probe.seen, ['/placeholder/4']);
  });

  testWidgets('the e2e start link is read once and offered as a held link', (
    tester,
  ) async {
    final tmp = Directory.systemTemp.createTempSync('e2e_link');
    addTearDown(() => tmp.deleteSync(recursive: true));
    expect(readE2eStartLink(tmp: tmp), isNull);
    File(
      '${tmp.path}/$e2eStartLinkFile',
    ).writeAsStringSync('miniclient://app/placeholder/42\n');
    final link = readE2eStartLink(tmp: tmp);
    expect(link, 'miniclient://app/placeholder/42');
    expect(readE2eStartLink(tmp: tmp), isNull, reason: 'deleted after reading');

    final links = PendingLinks.install(tester.binding);
    addTearDown(links.detach);
    links.offer(link!);
    expect(links.take(), '/placeholder/42');
    links
      ..detach()
      ..offer('/placeholder/1');
    expect(links.pending, isNull, reason: 'ignored once detached');
  });

  group('error hooks', () {
    // Plain tests: a widget test would see the replaced FlutterError.onError.
    late FlutterExceptionHandler? present;
    setUp(() {
      present = FlutterError.presentError;
      FlutterError.presentError = (_) {};
    });
    tearDown(() => FlutterError.presentError = present!);

    test('forward framework and async errors to Monitoring', () {
      final sink = InMemorySink();
      final monitoring = Monitoring([sink]);
      final before = FlutterError.onError;
      final restore = installErrorHooks(monitoring: () => monitoring);
      final installed = FlutterError.onError;
      restore();
      expect(installed, isNot(same(before)));
      expect(FlutterError.onError, same(before));

      final handled = platformErrorHook(() => monitoring)(
        StateError('async boom'),
        StackTrace.empty,
      );
      flutterErrorHook(() => monitoring)(
        FlutterErrorDetails(exception: StateError('sync')),
      );

      expect(handled, isTrue);
      final errors = sink.entries.whereType<ErrorEntry>().toList();
      expect(errors.map((e) => e.fatal), [true, false]);
      expect(errors.first.error.toString(), contains('async boom'));
      expect(errors.last.error.toString(), contains('sync'));
    });

    test('leave async errors unhandled before boot', () {
      final handled = platformErrorHook(() => null)(
        StateError('early'),
        StackTrace.empty,
      );
      expect(handled, isFalse);
    });
  });
}

class _Probe extends WidgetsBindingObserver {
  final List<String> seen = <String>[];

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    seen.add(routeInformation.uri.toString());
    return SynchronousFuture<bool>(true);
  }
}
