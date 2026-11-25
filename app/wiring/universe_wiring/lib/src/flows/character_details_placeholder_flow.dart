import 'package:flutter/material.dart';

/// Stands in for `characters_details`' flow at `/characters/:id`, so a route
/// builds a `*Flow` as R15 asks. Replaced by that feature's flow later.
class CharacterDetailsPlaceholderFlow extends StatelessWidget {
  const CharacterDetailsPlaceholderFlow({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      key: const Key('character.details.placeholder'),
      appBar: AppBar(title: Text('Character $id')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Character details $id', style: text.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'The full profile arrives with characters_details.',
              style: text.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
