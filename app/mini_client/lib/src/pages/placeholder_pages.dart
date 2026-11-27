import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_session/mc_session.dart';

/// Keys of the home's reading-list entry, for tests and the e2e journey.
const newReadingListKey = Key('home.reading_list.new');
const readingListResultKey = Key('home.reading_list.result');
const editReadingListKey = Key('home.reading_list.edit');

/// Shown when the reading lists changed without a result reaching home (the
/// editor was opened by a guard's `go(from)` after a sign-in, T-0066).
const readingListsChangedKey = Key('home.reading_list.changed');

/// Home's session entry (T-0066): who is signed in, and Sign in / Sign out.
const sessionStatusKey = Key('home.session.status');
const signInKey = Key('home.session.sign_in');
const signOutKey = Key('home.session.sign_out');

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
    required this.session,
    required this.onSignIn,
    required this.onSignOut,
    required this.dataChanges,
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

  /// Who is signed in (T-0066); home shows it and follows its changes.
  final SessionReader session;

  /// Opens the sign-in screen; completes once it ended.
  final Future<void> Function() onSignIn;

  /// Signs out.
  final Future<void> Function() onSignOut;

  /// The app's data-change events: home learns of a reading list the editor
  /// saved when no result reached it (T-0066, F-0049 note 11).
  final Stream<DataChanged> dataChanges;

  @override
  State<HomePlaceholderPage> createState() => _HomePlaceholderPageState();
}

/// The `mc_event_bus` topic the reading-list editor announces a save on
/// (library_reading_list_editor's `readingListsTopic`): a feature's constant
/// is not importable here, so the string is repeated and tested.
const _readingListsTopic = 'readingLists';

class _HomePlaceholderPageState extends State<HomePlaceholderPage> {
  /// The list the editor last returned, and whether it was new.
  ({String id, bool created})? _lastList;

  /// An editor is open: a second tap (New or Edit) is ignored until it
  /// returns, so one tap opens one editor.
  bool _awaiting = false;

  /// A reading list was saved by an editor nobody awaited: a guard sent the
  /// user to sign in, and after it `go(from)` built the editor with no
  /// caller, so its result cannot reach [_await]. The editor announces
  /// `DataChanged('readingLists')` once per save, which is how home learns
  /// (T-0066). A real home reloads its lists here; the placeholder says so.
  bool _listsChanged = false;

  StreamSubscription<DataChanged>? _changes;

  @override
  void initState() {
    super.initState();
    _changes = widget.dataChanges
        .where((change) => change.topic == _readingListsTopic)
        .listen(_onListsChanged);
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  /// While home awaits an editor, the result is on its way and says more
  /// (the id): the announcement is ignored then.
  void _onListsChanged(DataChanged _) {
    if (!_awaiting && mounted) {
      setState(() {
        _lastList = null;
        _listsChanged = true;
      });
    }
  }

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
    setState(() {
      _lastList = (id: id!, created: created);
      _listsChanged = false;
    });
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
          const McGap.md(),
          _SessionRow(
            session: widget.session,
            onSignIn: widget.onSignIn,
            onSignOut: widget.onSignOut,
          ),
          const McGap.xl(),
          McButton(label: 'Characters', onPressed: widget.onOpenCharacters),
          const McGap.md(),
          McButton(
            key: newReadingListKey,
            label: 'New reading list',
            onPressed: () => _await(widget.onNewReadingList, created: true),
          ),
          if (_listsChanged) ...[
            const McGap.sm(),
            Text(
              'Reading lists changed',
              key: readingListsChangedKey,
              style: text.titleMedium,
            ),
          ],
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

/// Who is signed in, with Sign in or Sign out (T-0066). It follows the
/// session's changes.
class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.onSignIn,
    required this.onSignOut,
  });

  final SessionReader session;
  final Future<void> Function() onSignIn;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthStatus>(
    stream: session.authState,
    initialData: session.status,
    builder: (context, _) {
      // Read from the session itself: the stream only says "changed".
      final userId = session.userId;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            userId == null ? 'Signed out' : 'Signed in as $userId',
            key: sessionStatusKey,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const McGap.sm(),
          if (userId == null)
            McButton(
              key: signInKey,
              label: 'Sign in',
              variant: McButtonVariant.secondary,
              onPressed: () => unawaited(onSignIn()),
            )
          else
            McButton(
              key: signOutKey,
              label: 'Sign out',
              variant: McButtonVariant.secondary,
              onPressed: () => unawaited(onSignOut()),
            ),
        ],
      );
    },
  );
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
