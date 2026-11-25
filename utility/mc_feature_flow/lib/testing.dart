import 'package:flutter/widgets.dart';
import 'package:mc_feature_flow/src/flow_context.dart';

/// Test aid: the current state of the flow [context] belongs to, as the
/// flow's controller holds it (the authoritative state the blocs update;
/// `flow_builder` itself sees only structural changes, F-0018).
///
/// [S] is the flow's state type. A feature keeps that type private (R4), so a
/// test outside the package passes `dynamic` and reads the fields it needs.
/// Fails naming the expected type when the flow's state is another type, and
/// when [context] is not below a [FeatureFlow].
///
/// Tests only: production code never reads flow state from a context.
S flowStateOf<S>(BuildContext context) {
  final controller = FlowScope.read(context).controller;
  if (controller == null) {
    throw StateError('The flow scope above $context has no controller.');
  }
  final state = controller.state;
  if (state is! S) {
    throw StateError(
      'The flow state is a ${state.runtimeType}, not the requested $S.',
    );
  }
  return state;
}
