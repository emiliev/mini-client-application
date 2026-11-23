import 'package:flutter/material.dart';

import 'counter_state.dart';
import 'greeting.dart';

/// The home page: a counter driven by the freezed [CounterState] union,
/// rendered with `state.when` (T-0014-AC6).
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onOpenDetail});

  /// Called with the current count when the detail button is tapped.
  final void Function(int count)? onOpenDetail;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CounterState _state = const CounterState.initial();

  @override
  Widget build(BuildContext context) {
    final label = _state.when(
      initial: () => 'Tap + to start',
      counting: (count) => 'Count: $count',
      failed: (reason) => 'Failed: $reason',
    );
    final count = _state.maybeWhen(counting: (c) => c, orElse: () => 0);
    return Scaffold(
      appBar: AppBar(title: Text(greeting())),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, key: const Key('counter_label')),
            Text(kindOf(_state), key: const Key('counter_kind')),
            TextButton(
              key: const Key('open_detail'),
              onPressed: () => widget.onOpenDetail?.call(count),
              child: const Text('Details'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('increment'),
        onPressed: () => setState(() => _state = increment(_state)),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// The detail page reached through the typed `DetailRoute`.
class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Detail')),
        body: Center(child: Text('Detail for $count', key: const Key('detail_label'))),
      );
}
