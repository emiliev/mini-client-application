import 'package:flutter/material.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';

/// The home placeholder until the discovery features exist (P1-17+).
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({
    required this.env,
    required this.onOpenPlaceholder,
    required this.onOpenCharacters,
    super.key,
  });

  /// The bundled config's environment (shows which asset was bundled).
  final String env;
  final ValueChanged<int> onOpenPlaceholder;
  final VoidCallback onOpenCharacters;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      key: const Key('home.placeholder'),
      appBar: AppBar(title: const Text('Mini Client')),
      body: ListView(
        padding: McInsets.screen,
        children: [
          Text('Marvel universe', style: text.headlineMedium),
          const McGap.sm(),
          Text(
            'Home placeholder. Features arrive with the exemplars.',
            style: text.bodyLarge,
          ),
          const McGap.lg(),
          Text('Typeface: Inter', style: text.titleMedium),
          const McGap.xs(),
          Text(
            'The quick brown fox jumps over the lazy dog. 0123456789',
            style: text.bodyMedium,
          ),
          Text(
            'Bold 700 · SemiBold 600 · Medium 500',
            style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w700),
          ),
          const McGap.lg(),
          Text('Config: env=$env', style: text.labelLarge),
          const McGap.xl(),
          McButton(label: 'Characters', onPressed: onOpenCharacters),
          const McGap.md(),
          McButton(
            label: 'Open placeholder 7',
            onPressed: () => onOpenPlaceholder(7),
          ),
        ],
      ),
    );
  }
}

/// The placeholder detail route: the deep-link target until real features.
class PlaceholderDetailPage extends StatelessWidget {
  const PlaceholderDetailPage({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      key: const Key('placeholder.detail'),
      appBar: AppBar(title: Text('Placeholder $id')),
      body: Padding(
        padding: McInsets.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Placeholder detail $id', style: text.headlineMedium),
            const McGap.sm(),
            Text(
              'Deep link: miniclient://app/placeholder/$id',
              style: text.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// Unknown paths (plan 01 §4.2 "Unknown paths go to … not-found page").
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({required this.location, super.key});

  final String location;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('not.found'),
    appBar: AppBar(title: const Text('Not found')),
    body: Padding(
      padding: McInsets.screen,
      child: Text('Nothing lives at $location'),
    ),
  );
}
