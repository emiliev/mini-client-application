import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One flow the catalogue opens: a generated feature and where its route
/// is (T-0074, P2-08). `mcgen wire` writes the list (`catalogueEntries`).
class CatalogueEntry {
  const CatalogueEntry({required this.module, required this.location});

  /// The feature package, which is also its route's (and screen's) name.
  final String module;

  /// The location its route matches (`GeneratedLocations.<module>`).
  final String location;
}

/// The key of an entry's tile.
Key catalogueEntryKey(String module) => ValueKey<String>('catalogue.$module');

/// The key of the text shown when there is nothing to list.
const Key catalogueEmptyKey = ValueKey<String>('catalogue.empty');

/// `/catalogue` (T-0074, P2-08): a debug screen that lists every generated
/// flow, so each is reachable without a hand-written entry point. Home has
/// no link to it, and release builds have no such route (`buildAppRouter`).
/// A tile pushes the flow's location, so Back returns here.
class CataloguePage extends StatelessWidget {
  const CataloguePage({required this.entries, super.key});

  final List<CatalogueEntry> entries;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Catalogue')),
    body: entries.isEmpty
        ? const Center(
            child: Text('No generated flows yet', key: catalogueEmptyKey),
          )
        : ListView(
            children: [
              for (final e in entries)
                ListTile(
                  key: catalogueEntryKey(e.module),
                  title: Text(e.module),
                  subtitle: Text(e.location),
                  onTap: () => unawaited(context.push(e.location)),
                ),
            ],
          ),
  );
}
