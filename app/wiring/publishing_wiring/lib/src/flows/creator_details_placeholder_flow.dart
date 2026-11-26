import 'package:flutter/material.dart';

/// Stands in for `creators_details`' flow at `/creators/:id`, so a route
/// builds a `*Flow` as R15 asks. Replaced by that feature's flow later.
class CreatorDetailsPlaceholderFlow extends StatelessWidget {
  const CreatorDetailsPlaceholderFlow({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      key: const Key('creator.details.placeholder'),
      appBar: AppBar(title: Text('Creator $id')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Creator details $id', style: text.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'The creator page arrives with creators_details.',
              style: text.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
