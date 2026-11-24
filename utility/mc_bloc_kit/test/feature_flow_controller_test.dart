import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:test/test.dart';

void main() {
  test('T-0022-AC3 complete emits the result exactly once', () {
    final controller = FeatureFlowController<int>(0);
    final results = <Object?>[];
    controller.completions.listen(results.add);
    controller
      ..complete('first')
      ..complete('second');
    expect(results, ['first']);
    expect(controller.isCompleted, isTrue);
    expect(controller.result, 'first');
  });

  test('T-0022-AC5 update and restore both notify states', () {
    final controller = FeatureFlowController<int>(0);
    final seen = <int>[];
    controller.states.listen(seen.add);
    controller
      ..update((s) => s + 1)
      ..restore(0);
    expect(seen, [1, 0]);
    expect(controller.state, 0);
  });

  test('T-0022-AC3 update after completion is ignored', () {
    final controller = FeatureFlowController<int>(0)
      ..complete()
      ..update((s) => s + 1);
    expect(controller.state, 0);
  });

  test(
    'T-0022-AC3 a late update, restore or complete after dispose is a no-op',
    () async {
      final controller = FeatureFlowController<int>(0);
      final results = <Object?>[];
      controller.completions.listen(results.add);
      await controller.dispose();
      expect(() => controller.update((s) => s + 1), returnsNormally);
      expect(() => controller.restore(5), returnsNormally);
      expect(() => controller.complete('late'), returnsNormally);
      expect(controller.state, 0);
      expect(controller.isCompleted, isFalse);
      expect(results, isEmpty);
    },
  );
}
