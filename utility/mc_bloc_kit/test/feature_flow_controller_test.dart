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

  test('T-0022-AC3 update notifies states; restore does not', () {
    final controller = FeatureFlowController<int>(0);
    final seen = <int>[];
    controller.states.listen(seen.add);
    controller
      ..update((s) => s + 1)
      ..restore(0);
    expect(seen, [1]);
    expect(controller.state, 0);
  });

  test('T-0022-AC3 update after completion is ignored', () {
    final controller = FeatureFlowController<int>(0)
      ..complete()
      ..update((s) => s + 1);
    expect(controller.state, 0);
  });
}
