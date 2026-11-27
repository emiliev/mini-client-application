// T-0056-AC7: the flag step sets what a feature reads, and goes red where it
// should (negative controls), over the test container's stub snapshot.
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_feature_flags/mc_feature_flags.dart';
import 'package:mc_test_steps/mc_test_steps.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

enum _Layout { grid, list }

const _featured = FeatureFlag<bool>(
  key: 'store.home_featured',
  defaultValue: true,
  description: 'The featured section.',
  codec: BoolFlagCodec(),
);

const _count = FeatureFlag<int>(
  key: 'store.count',
  defaultValue: 6,
  description: 'How many.',
  codec: IntFlagCodec(),
);

const _layout = FeatureFlag<_Layout>(
  key: 'store.layout',
  defaultValue: _Layout.grid,
  description: 'The layout.',
  codec: EnumFlagCodec<_Layout>(_Layout.values),
);

Future<FeatureFlagsReader> _boot() async {
  await McTestContainer.initialize(McTestSession.current);
  return diContainer<FeatureFlagsReader>();
}

void main() {
  mcTestWidgets('T-0056-AC7 the flag {key} is {value}: literals and JSON '
      'text reach the feature', (tester) async {
    await theFlagIs(tester, 'store.home_featured', false);
    await theFlagIs(tester, 'store.count', '3');
    await theFlagIs(tester, 'store.layout', 'list');
    final flags = await _boot();

    expect(flags.value(_featured), isFalse);
    expect(flags.value(_count), 3);
    expect(flags.value(_layout), _Layout.list);

    await theFlagIs(tester, 'store.home_featured', 'true');
    expect(flags.value(_featured), isTrue);
  });

  mcTestWidgets('T-0056-AC7 negative controls: no step is the default, '
      'another key changes nothing, a wrong type is the default', (
    tester,
  ) async {
    final flags = await _boot();
    expect(flags.value(_featured), isTrue, reason: 'no step: the default');

    await theFlagIs(tester, 'store.home_featured_x', false);
    expect(flags.value(_featured), isTrue, reason: 'another key');

    await theFlagIs(tester, 'store.home_featured', 'off');
    expect(flags.value(_featured), isTrue, reason: 'a string, not a bool');

    await theFlagIs(tester, 'store.count', 3.5);
    expect(flags.value(_count), 6, reason: 'not an int');
  });
}
