import 'package:discovery_search/src/l10n/discovery_search_l10n.dart';
import 'package:discovery_search/src/presentation/bloc/discovery_search_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';

/// Key of the recent searches list, for tests.
const searchHistoryKey = ValueKey<String>('discovery_search.history');

/// Key of the inline error after a Clear that failed, for tests.
const searchClearFailedKey = ValueKey<String>(
  'discovery_search.history.clear_failed',
);

/// Key of the hint shown while there are no recent searches, for tests.
const searchNoHistoryKey = ValueKey<String>('discovery_search.history.none');

/// The recent searches, most recent first, with "Clear". Tapping one puts it
/// back in the field ([onPick]), which searches it at once. After a Clear
/// that failed ([clearFailed]) the list stays and an inline error says so.
class SearchHistoryView extends StatelessWidget {
  const SearchHistoryView({
    required this.history,
    required this.onPick,
    this.clearFailed = false,
    super.key,
  });

  final List<String> history;
  final bool clearFailed;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = DiscoverySearchL10n.of(context);
    if (history.isEmpty) {
      return Padding(
        key: searchNoHistoryKey,
        padding: McInsets.screen,
        child: Text(
          l10n.discoverySearchNoRecent,
          textAlign: TextAlign.center,
          style:
              Theme.of(
                    context,
                  ).textTheme.bodyLarge!
                  .copyWith(color: context.mcPalette.onSurfaceMuted),
        ),
      );
    }
    return ListView(
      key: searchHistoryKey,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        McSectionHeader(
          title: l10n.discoverySearchRecent,
          actionLabel: l10n.discoverySearchClearRecent,
          onAction: () => context.read<DiscoverySearchBloc>().add(
            const DiscoverySearchEvent.clearHistory(),
          ),
        ),
        if (clearFailed)
          Padding(
            key: searchClearFailedKey,
            padding: McInsets.horizontal,
            child: Semantics(
              liveRegion: true,
              child: Text(
                l10n.discoverySearchClearFailed,
                style:
                    Theme.of(
                          context,
                        ).textTheme.bodyMedium!
                        .copyWith(color: context.mcPalette.error),
              ),
            ),
          ),
        for (final query in history)
          ListTile(
            leading: const ExcludeSemantics(child: Icon(Icons.history)),
            title: Text(query),
            onTap: () => onPick(query),
          ),
      ],
    );
  }
}
