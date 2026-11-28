import 'dart:convert';
import 'dart:io';

import 'package:l10n_check/l10n_check.dart';
import 'package:test/test.dart';

/// The gate: every ARB set in the workspace (the `arbs` filegroups listed in
/// this package's BUILD.bazel `workspace_gate_test` data) is complete.
void main() {
  test('T-0025-AC3 the workspace ARB sets are complete (gate)', () {
    final root = Directory.current.path;
    final arbs = Directory(root)
        .listSync(recursive: true, followLinks: false)
        .where((e) => e.path.endsWith('.arb'))
        .toList();
    expect(arbs, isNotEmpty, reason: 'no ARB files in runfiles at $root');
    expect(checkL10n(root), isEmpty);
  });

  test('T-0032-AC4 the gate checks the characters_list ARB set', () {
    const dir = 'feature/characters/characters_list/lib/src/l10n';
    for (final locale in ['en', 'de', 'en_XA']) {
      expect(
        File('$dir/characters_list_$locale.arb').existsSync(),
        isTrue,
        reason: 'characters_list_$locale.arb is not in the gate runfiles',
      );
    }
    // The same files with one German key removed: the check must name it,
    // so the gate really reads this package's set.
    final copy = Directory.systemTemp.createTempSync('l10n_gate_');
    addTearDown(() => copy.deleteSync(recursive: true));
    final target = Directory('${copy.path}/$dir')..createSync(recursive: true);
    for (final arb in Directory(dir).listSync().whereType<File>()) {
      arb.copySync('${target.path}/${arb.uri.pathSegments.last}');
    }
    final de = File('${target.path}/characters_list_de.arb');
    final json = jsonDecode(de.readAsStringSync()) as Map<String, dynamic>
      ..remove('charactersListTitle');
    de.writeAsStringSync(jsonEncode(json));

    expect(
      checkL10n(copy.path).map((v) => '$v'),
      contains(
        allOf(
          contains('characters_list'),
          contains('de'),
          contains('charactersListTitle'),
        ),
      ),
    );
  });

  test('T-0041-AC8 the gate checks the comics_details ARB set', () {
    const dir = 'feature/comics/comics_details/lib/src/l10n';
    for (final locale in ['en', 'de', 'en_XA']) {
      expect(
        File('$dir/comics_details_$locale.arb').existsSync(),
        isTrue,
        reason: 'comics_details_$locale.arb is not in the gate runfiles',
      );
    }
    // The same files with one pseudo-locale key removed: the check must name
    // it, so the gate really reads this package's set.
    final copy = Directory.systemTemp.createTempSync('l10n_gate_');
    addTearDown(() => copy.deleteSync(recursive: true));
    final target = Directory('${copy.path}/$dir')..createSync(recursive: true);
    for (final arb in Directory(dir).listSync().whereType<File>()) {
      arb.copySync('${target.path}/${arb.uri.pathSegments.last}');
    }
    final xa = File('${target.path}/comics_details_en_XA.arb');
    final json = jsonDecode(xa.readAsStringSync()) as Map<String, dynamic>
      ..remove('comicsDetailsFavouriteAdd');
    xa.writeAsStringSync(jsonEncode(json));

    expect(
      checkL10n(copy.path).map((v) => '$v'),
      contains(
        allOf(
          contains('comics_details'),
          contains('en_XA'),
          contains('comicsDetailsFavouriteAdd'),
        ),
      ),
    );
  });

  test('T-0067-AC4 the gate checks the characters_details ARB set', () {
    const dir = 'feature/characters/characters_details/lib/src/l10n';
    for (final locale in ['en', 'de', 'en_XA']) {
      expect(
        File('$dir/characters_details_$locale.arb').existsSync(),
        isTrue,
        reason: 'characters_details_$locale.arb is not in the gate runfiles',
      );
    }
    // The same files with one pseudo-locale key removed: the check must name
    // it, so the gate really reads this package's set.
    final copy = Directory.systemTemp.createTempSync('l10n_gate_');
    addTearDown(() => copy.deleteSync(recursive: true));
    final target = Directory('${copy.path}/$dir')..createSync(recursive: true);
    for (final arb in Directory(dir).listSync().whereType<File>()) {
      arb.copySync('${target.path}/${arb.uri.pathSegments.last}');
    }
    final xa = File('${target.path}/characters_details_en_XA.arb');
    final json = jsonDecode(xa.readAsStringSync()) as Map<String, dynamic>
      ..remove('characterDetailsStatsLabel');
    xa.writeAsStringSync(jsonEncode(json));

    expect(
      checkL10n(copy.path).map((v) => '$v'),
      contains(
        allOf(
          contains('characters_details'),
          contains('en_XA'),
          contains('characterDetailsStatsLabel'),
        ),
      ),
    );
  });

  test('T-0071-AC6 the gate checks the characters_search ARB set', () {
    const dir = 'feature/characters/characters_search/lib/src/l10n';
    for (final locale in ['en', 'de', 'en_XA']) {
      expect(
        File('$dir/characters_search_$locale.arb').existsSync(),
        isTrue,
        reason: 'characters_search_$locale.arb is not in the gate runfiles',
      );
    }
    // The same files with one German key removed: the check must name it,
    // so the gate really reads this package's set.
    final copy = Directory.systemTemp.createTempSync('l10n_gate_');
    addTearDown(() => copy.deleteSync(recursive: true));
    final target = Directory('${copy.path}/$dir')..createSync(recursive: true);
    for (final arb in Directory(dir).listSync().whereType<File>()) {
      arb.copySync('${target.path}/${arb.uri.pathSegments.last}');
    }
    final de = File('${target.path}/characters_search_de.arb');
    final json = jsonDecode(de.readAsStringSync()) as Map<String, dynamic>
      ..remove('charactersSearchSortNewest');
    de.writeAsStringSync(jsonEncode(json));

    expect(
      checkL10n(copy.path).map((v) => '$v'),
      contains(
        allOf(
          contains('characters_search'),
          contains('de'),
          contains('charactersSearchSortNewest'),
        ),
      ),
    );
  });

  test('T-0046-AC8 the gate checks the discovery_search ARB set', () {
    const dir = 'feature/discovery/discovery_search/lib/src/l10n';
    for (final locale in ['en', 'de', 'en_XA']) {
      expect(
        File('$dir/discovery_search_$locale.arb').existsSync(),
        isTrue,
        reason: 'discovery_search_$locale.arb is not in the gate runfiles',
      );
    }
    // The same files with one German key removed: the check must name it,
    // so the gate really reads this package's set.
    final copy = Directory.systemTemp.createTempSync('l10n_gate_');
    addTearDown(() => copy.deleteSync(recursive: true));
    final target = Directory('${copy.path}/$dir')..createSync(recursive: true);
    for (final arb in Directory(dir).listSync().whereType<File>()) {
      arb.copySync('${target.path}/${arb.uri.pathSegments.last}');
    }
    final de = File('${target.path}/discovery_search_de.arb');
    final json = jsonDecode(de.readAsStringSync()) as Map<String, dynamic>
      ..remove('discoverySearchShowMore');
    de.writeAsStringSync(jsonEncode(json));

    expect(
      checkL10n(copy.path).map((v) => '$v'),
      contains(
        allOf(
          contains('discovery_search'),
          contains('de'),
          contains('discoverySearchShowMore'),
        ),
      ),
    );
  });

  test(
    'T-0048-AC8 the gate checks the library_reading_list_editor ARB set',
    () {
      const dir = 'feature/library/library_reading_list_editor/lib/src/l10n';
      for (final locale in ['en', 'de', 'en_XA']) {
        expect(
          File('$dir/library_reading_list_editor_$locale.arb').existsSync(),
          isTrue,
          reason:
              'library_reading_list_editor_$locale.arb is not in the gate '
              'runfiles',
        );
      }
      // The same files with one German key removed: the check must name it,
      // so the gate really reads this package's set.
      final copy = Directory.systemTemp.createTempSync('l10n_gate_');
      addTearDown(() => copy.deleteSync(recursive: true));
      final target = Directory('${copy.path}/$dir')
        ..createSync(recursive: true);
      for (final arb in Directory(dir).listSync().whereType<File>()) {
        arb.copySync('${target.path}/${arb.uri.pathSegments.last}');
      }
      final de = File('${target.path}/library_reading_list_editor_de.arb');
      final json = jsonDecode(de.readAsStringSync()) as Map<String, dynamic>
        ..remove('readingListEditorNameRequired');
      de.writeAsStringSync(jsonEncode(json));

      expect(
        checkL10n(copy.path).map((v) => '$v'),
        contains(
          allOf(
            contains('library_reading_list_editor'),
            contains('de'),
            contains('readingListEditorNameRequired'),
          ),
        ),
      );
    },
  );

  test('T-0056-AC8 the gate checks the store_home ARB set', () {
    const dir = 'feature/store/store_home/lib/src/l10n';
    for (final locale in ['en', 'de', 'en_XA']) {
      expect(
        File('$dir/store_home_$locale.arb').existsSync(),
        isTrue,
        reason: 'store_home_$locale.arb is not in the gate runfiles',
      );
    }
    // The same files with one German key removed: the check must name it,
    // so the gate really reads this package's set.
    final copy = Directory.systemTemp.createTempSync('l10n_gate_');
    addTearDown(() => copy.deleteSync(recursive: true));
    final target = Directory('${copy.path}/$dir')..createSync(recursive: true);
    for (final arb in Directory(dir).listSync().whereType<File>()) {
      arb.copySync('${target.path}/${arb.uri.pathSegments.last}');
    }
    final de = File('${target.path}/store_home_de.arb');
    final json = jsonDecode(de.readAsStringSync()) as Map<String, dynamic>
      ..remove('storeHomeDealEndsIn');
    de.writeAsStringSync(jsonEncode(json));

    expect(
      checkL10n(copy.path).map((v) => '$v'),
      contains(
        allOf(
          contains('store_home'),
          contains('de'),
          contains('storeHomeDealEndsIn'),
        ),
      ),
    );
  });

  test('T-0063-AC7 the gate checks the settings_appearance ARB set', () {
    const dir = 'feature/settings/settings_appearance/lib/src/l10n';
    for (final locale in ['en', 'de', 'en_XA']) {
      expect(
        File('$dir/settings_appearance_$locale.arb').existsSync(),
        isTrue,
        reason: 'settings_appearance_$locale.arb is not in the gate runfiles',
      );
    }
    // The same files with one German key removed: the check must name it,
    // so the gate really reads this package's set.
    final copy = Directory.systemTemp.createTempSync('l10n_gate_');
    addTearDown(() => copy.deleteSync(recursive: true));
    final target = Directory('${copy.path}/$dir')..createSync(recursive: true);
    for (final arb in Directory(dir).listSync().whereType<File>()) {
      arb.copySync('${target.path}/${arb.uri.pathSegments.last}');
    }
    final de = File('${target.path}/settings_appearance_de.arb');
    final json = jsonDecode(de.readAsStringSync()) as Map<String, dynamic>
      ..remove('settingsAppearanceSyncOffline');
    de.writeAsStringSync(jsonEncode(json));

    expect(
      checkL10n(copy.path).map((v) => '$v'),
      contains(
        allOf(
          contains('settings_appearance'),
          contains('de'),
          contains('settingsAppearanceSyncOffline'),
        ),
      ),
    );
  });

  test('T-0070-AC5 the gate checks the settings_home ARB set', () {
    const dir = 'feature/settings/settings_home/lib/src/l10n';
    for (final locale in ['en', 'de', 'en_XA']) {
      expect(
        File('$dir/settings_home_$locale.arb').existsSync(),
        isTrue,
        reason: 'settings_home_$locale.arb is not in the gate runfiles',
      );
    }
    // The same files with one German key removed: the check must name it,
    // so the gate really reads this package's set.
    final copy = Directory.systemTemp.createTempSync('l10n_gate_');
    addTearDown(() => copy.deleteSync(recursive: true));
    final target = Directory('${copy.path}/$dir')..createSync(recursive: true);
    for (final arb in Directory(dir).listSync().whereType<File>()) {
      arb.copySync('${target.path}/${arb.uri.pathSegments.last}');
    }
    final de = File('${target.path}/settings_home_de.arb');
    final json = jsonDecode(de.readAsStringSync()) as Map<String, dynamic>
      ..remove('settingsHomeSignOut');
    de.writeAsStringSync(jsonEncode(json));

    expect(
      checkL10n(copy.path).map((v) => '$v'),
      contains(
        allOf(
          contains('settings_home'),
          contains('de'),
          contains('settingsHomeSignOut'),
        ),
      ),
    );
  });
}
