import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';

/// Keys of the home's reading-list entry, for tests and the e2e journey.
const newReadingListKey = Key('home.reading_list.new');
const readingListResultKey = Key('home.reading_list.result');
const editReadingListKey = Key('home.reading_list.edit');

/// The not-found screen's "Go home" button.
const notFoundHomeKey = Key('not.found.home');

/// The home placeholder until the discovery features exist (P1-17+).
///
/// Its "New reading list" entry is the first caller of a flow that ends with
/// a result (plan 01 §4.3, T-0048): it awaits [onNewReadingList] (the
/// editor's route, pushed through `AppFlows`) and shows the list it returns.
class HomePlaceholderPage extends StatefulWidget {
  const HomePlaceholderPage({
    required this.env,
    required this.onOpenPlaceholder,
    required this.onOpenCharacters,
    required this.onOpenSearch,
    required this.onOpenStore,
    required this.onOpenTrivia,
    required this.onOpenSettings,
    required this.onNewReadingList,
    required this.onEditReadingList,
    super.key,
  });

  /// The bundled config's environment (shows which asset was bundled).
  final String env;
  final ValueChanged<int> onOpenPlaceholder;
  final VoidCallback onOpenCharacters;
  final VoidCallback onOpenSearch;

  /// Opens the store (T-0056).
  final VoidCallback onOpenStore;

  /// Opens the trivia quiz (T-0064).
  final VoidCallback onOpenTrivia;

  /// Opens the appearance settings (T-0063).
  final VoidCallback onOpenSettings;

  /// Opens the editor on a new list; completes with its id, or null.
  final Future<String?> Function() onNewReadingList;

  /// Opens the editor on list `id`; completes with the id once saved.
  final Future<String?> Function(String id) onEditReadingList;

  @override
  State<HomePlaceholderPage> createState() => _HomePlaceholderPageState();
}

class _HomePlaceholderPageState extends State<HomePlaceholderPage> {
  /// The list the editor last returned, and whether it was new.
  ({String id, bool created})? _lastList;

  /// An editor is open: a second tap (New or Edit) is ignored until it
  /// returns, so one tap opens one editor.
  bool _awaiting = false;

  Future<void> _await(
    Future<String?> Function() open, {
    required bool created,
  }) async {
    if (_awaiting) {
      return;
    }
    _awaiting = true;
    final String? id;
    try {
      id = await open();
    } finally {
      _awaiting = false;
    }
    if (!mounted || id == null) {
      return;
    }
    setState(() => _lastList = (id: id!, created: created));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final last = _lastList;
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
          Text('Config: env=${widget.env}', style: text.labelLarge),
          const McGap.xl(),
          McButton(label: 'Characters', onPressed: widget.onOpenCharacters),
          const McGap.md(),
          McButton(
            key: newReadingListKey,
            label: 'New reading list',
            onPressed: () => _await(widget.onNewReadingList, created: true),
          ),
          if (last != null) ...[
            const McGap.sm(),
            Text(
              last.created
                  ? 'List created: ${last.id}'
                  : 'List saved: ${last.id}',
              key: readingListResultKey,
              style: text.titleMedium,
            ),
            const McGap.sm(),
            McButton(
              key: editReadingListKey,
              label: 'Edit list ${last.id}',
              variant: McButtonVariant.secondary,
              onPressed: () => _await(
                () => widget.onEditReadingList(last.id),
                created: false,
              ),
            ),
          ],
          const McGap.md(),
          McButton(label: 'Search', onPressed: widget.onOpenSearch),
          const McGap.md(),
          McButton(label: 'Store', onPressed: widget.onOpenStore),
          const McGap.md(),
          McButton(
            label: 'Open placeholder 7',
            onPressed: () => widget.onOpenPlaceholder(7),
          ),
          // Last, so the entries above keep their place on screen (T-0064).
          const McGap.md(),
          McButton(label: 'Trivia', onPressed: widget.onOpenTrivia),
          const McGap.md(),
          McButton(label: 'Settings', onPressed: widget.onOpenSettings),
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

/// Unknown paths and bad ids (plan 01 §4.2 "Unknown paths go to … not-found
/// page"). It always has a way home (T-0054, P-097): Back pops when something
/// is below, and goes home when not; "Go home" goes home.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({required this.location, super.key});

  final String location;

  void _home(BuildContext context) =>
      GoRouter.of(context).go(AppLocations.home);

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('not.found'),
    appBar: AppBar(
      title: const Text('Not found'),
      leading: BackButton(
        onPressed: () {
          if (GoRouter.of(context).canPop()) {
            GoRouter.of(context).pop();
          } else {
            _home(context);
          }
        },
      ),
    ),
    body: Padding(
      padding: McInsets.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nothing lives at $location'),
          const McGap.lg(),
          McButton(
            key: notFoundHomeKey,
            label: 'Go home',
            onPressed: () => _home(context),
          ),
        ],
      ),
    ),
  );
}
