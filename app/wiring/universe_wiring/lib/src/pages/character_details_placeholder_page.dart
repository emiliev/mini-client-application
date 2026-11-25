import 'package:flutter/material.dart';

/// Stands in for `characters_details` at `/characters/:id`.
class CharacterDetailsPlaceholderPage extends StatelessWidget {
  const CharacterDetailsPlaceholderPage({required this.id, super.key});

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
