import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation_channel_support.dart';

/// T-0035: the framework's own answers on `flutter/navigation`, in a target
/// where no `FlowBuilder` ever mounts, so they cannot depend on test order.
/// `flow_navigation_channel_test.dart` compares the flow cases with the same
/// constants.
void main() {
  testWidgets('T-0035-AC2 baseline: the framework answers the script as '
      'recorded, with no flow ever mounted', (tester) async {
    final delegate = await mountRouter(tester, ValueNotifier(const SizedBox()));

    expect(await runScript(tester), frameworkReplies);
    expect(asStrings(delegate), frameworkLocations);
    expect(delegate.pops, 1);
  });

  testWidgets('T-0035-AC1 control: a link reaches the router with no flow '
      'mounted', (tester) async {
    final delegate = await mountRouter(tester, ValueNotifier(const SizedBox()));

    expect(await sendLink(tester, '/before'), true);
    expect(delegate.locations.last.path, '/before');
  });
}
