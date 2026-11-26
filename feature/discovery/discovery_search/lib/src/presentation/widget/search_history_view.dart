import 'package:discovery_search/src/l10n/discovery_search_l10n.dart';
import 'package:discovery_search/src/presentation/bloc/discovery_search_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';

/// Key of the recent searches list, for tests.
const searchHistoryKey = ValueKey<String>('discovery_search.history');

/// Key of the hint shown while there are no recent searches, for tests.
const searchNoHistoryKey = ValueKey<String>('discovery_search.history.none');

/// The recent searches, most recent first, with "Clear". Tapping one puts it
/// back in the field ([onPick]), which searches it as if it had been typed.
class SearchHistoryView extends StatelessWidget {
  const SearchHistoryView({
    required this.history,
    required this.onPick,
    super.key,
  });

  final List<String> history;
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
