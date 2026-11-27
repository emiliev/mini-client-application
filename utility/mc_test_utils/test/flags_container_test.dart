// P-107 (T-0056): the test container registers the session's stub flag
// snapshot as the root's FeatureFlagsReader, so a feature test can resolve
// flags and set them, and no `/v1/flags` request reaches the strict harness.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_feature_flags/mc_feature_flags.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

enum _Layout { grid, list }

const _featured = FeatureFlag<bool>(
  key: 'test.featured',
  defaultValue: true,
  description: 'A section that can be switched off.',
  codec: BoolFlagCodec(),
);

const _limit = FeatureFlag<int>(
  key: 'test.limit',
  defaultValue: 3,
  description: 'How many.',
  codec: IntFlagCodec(),
);

const _layout = FeatureFlag<_Layout>(
  key: 'test.layout',
  defaultValue: _Layout.grid,
  description: 'Which layout.',
  codec: EnumFlagCodec<_Layout>(_Layout.values),
);

const _experiment = Experiment(
  key: 'test.experiment',
  variants: [ExperimentVariant('control', 1), ExperimentVariant('rich', 1)],
);

void main() {
  mcTestWidgets('T-0056-AC7 the container registers the session\'s stub as '
      'the FeatureFlagsReader and sends no request', (tester) async {
    final session = McTestSession.current;
    await McTestContainer.initialize(session);

    final flags = diContainer<FeatureFlagsReader>();
    expect(flags, same(session.flags));
    expect(flags.value(_featured), isTrue, reason: 'the default');
    await flags.refresh();
    expect(session.backend.requests, isEmpty);
    expect(session.flags.readKeys, {'test.featured'});
  });

  mcTestWidgets('T-0056-AC7 a set value is decoded with the flag\'s codec; '
      'a wrong type or a removed value is the default', (tester) async {
    final flags = McTestSession.current.flags
      ..set('test.featured', false)
      ..set('test.limit', 7)
      ..set('test.layout', 'list');
    expect(flags.value(_featured), isFalse);
    expect(flags.value(_limit), 7);
    expect(flags.value(_layout), _Layout.list);

    flags
      ..set('test.featured', 'no')
      ..set('test.limit', 7.5)
      ..set('test.layout', 'carousel');
    expect(flags.value(_featured), isTrue);
    expect(flags.value(_limit), 3);
    expect(flags.value(_layout), _Layout.grid);

    flags
      ..set('test.featured', false)
      ..set('test.featured', null);
    expect(flags.value(_featured), isTrue);
    expect(() => flags.set(' ', true), throwsArgumentError);
  });

  mcTestWidgets('T-0056-AC7 watch gives the value, then each distinct '
      'change, until cancelled', (tester) async {
    final flags = McTestSession.current.flags;
    final seen = <bool>[];
    final subscription = flags.watch(_featured).listen(seen.add);
    await tester.pump();
    flags
      ..set('test.featured', true)
      ..set('test.featured', false)
      ..set('test.other', false)
      ..set('test.featured', false);
    await tester.pump();
    expect(seen, [true, false]);

    // Not awaited: a cancel future is made in the root zone and never
    // completes under fake async (F-0052 trap 1).
    unawaited(subscription.cancel());
    await tester.pump();
    flags.set('test.featured', true);
    await tester.pump();
    expect(seen, [true, false]);
  });

  mcTestWidgets('T-0056-AC7 an experiment is its control unless a declared '
      'variant is forced', (tester) async {
    final flags = McTestSession.current.flags;
    expect(flags.variant(_experiment), 'control');
    flags.forceVariant('test.experiment', 'unknown');
    expect(flags.variant(_experiment), 'control');
    flags.forceVariant('test.experiment', 'rich');
    expect(flags.variant(_experiment), 'rich');
    unawaited(flags.refresh());
  });
}
