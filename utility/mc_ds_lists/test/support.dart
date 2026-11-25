import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_paging/mc_paging.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// A [PagedState] of `n` ints with more to load, unless overridden.
PagedState<int> pagedState(
  int n, {
  bool hasReachedEnd = false,
  bool isLoadingMore = false,
  ApiFailure? failure,
}) => PagedState<int>(
  items: List<int>.generate(n, (i) => i),
  request: PageRequest(offset: n, limit: 20),
  hasReachedEnd: hasReachedEnd,
  isLoadingMore: isLoadingMore,
  failure: failure,
  total: 100,
);

/// Hosts [child] on a sized surface, so scroll tests drive real gestures
/// against a real viewport.
Future<void> pumpOnSurface(
  WidgetTester tester,
  Widget child, {
  double width = 375,
  double height = 600,
}) async {
  mcSetSurface(tester, width, height);
  await tester.pumpWidget(
    mcGoldenApp(
      child: SizedBox(width: width, height: height, child: child),
    ),
  );
  await tester.pump();
}

double scrollPixels(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

double maxScroll(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .maxScrollExtent;
