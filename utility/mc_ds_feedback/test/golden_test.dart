import 'package:flutter/material.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_testing/mc_ds_testing.dart';

void main() {
  mcGoldenMatrix(
    acId: 'T-0019-AC1',
    component: 'loading',
    settle: const Duration(milliseconds: 700),
    builder: (_) => const SizedBox(height: 200, child: McLoading()),
    height: 220,
    heightAtScale2: 220,
  );
  mcGoldenMatrix(
    acId: 'T-0019-AC1',
    component: 'error_view',
    builder: (_) => SizedBox(
      width: 375,
      child: McErrorView(
        message:
            'We could not reach the Marvel archive. Check your connection.',
        onRetry: () {},
      ),
    ),
    height: 420,
    heightAtScale2: 760,
  );
  mcGoldenMatrix(
    acId: 'T-0019-AC1',
    component: 'empty_view',
    builder: (_) => const SizedBox(
      width: 375,
      child: McEmptyView(message: 'No characters match your search.'),
    ),
    height: 360,
    heightAtScale2: 640,
  );
}
