import 'dart:convert';
import 'dart:io';

/// Locales every package that has ARB files must provide. The pseudo-locale
/// `en_XA` is optional (R24); when present its keys are checked too.
const List<String> defaultRequiredLocales = ['en', 'de'];

/// Checks every `lib/src/l10n/` ARB set under [root].
///
/// For each package that has ARB files, the template is `<pkg>_en.arb` and:
/// - every locale in [requiredLocales] must have a file, else
///   `pkg: missing locale de (expected pkg_de.arb)`;
/// - every locale file has exactly the template's message keys, else
///   `pkg: locale de is missing key foo` / `has unknown key foo`;
/// - `@@locale` agrees with the file name.
///
/// Symlinks are never followed, and Bazel's `bazel-*` links, `external/`,
/// `.dart_tool`, `.fvm`, `.git` and `build` are skipped.
///
/// Returns one message per violation; empty means the check passed.
List<String> checkL10n(
  String root, {
  List<String> requiredLocales = defaultRequiredLocales,
}) {
  final violations = <String>[];
  final sets = <String, List<File>>{};
  _collect(Directory(root), sets);
  for (final entry in sets.entries) {
    violations.addAll(_checkPackage(entry.key, entry.value, requiredLocales));
  }
  violations.sort();
  return violations;
}

bool _skipDir(String name) =>
    name.startsWith('bazel-') ||
    name == 'external' ||
    name == '.dart_tool' ||
    name == '.fvm' ||
    name == '.git' ||
    name == 'build';

void _collect(Directory dir, Map<String, List<File>> sets) {
  final List<FileSystemEntity> entries;
  try {
    entries = dir.listSync(followLinks: false);
  } on FileSystemException {
    return;
  }
  for (final entity in entries) {
    final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    if (entity is Directory) {
      if (!_skipDir(name)) {
        _collect(entity, sets);
      }
    } else if (name.endsWith('.arb') &&
        (entity is File ||
            // A symlinked *file* (Bazel runfiles) counts; symlinked
            // directories are never followed.
            (entity is Link && FileSystemEntity.isFileSync(entity.path)))) {
      final file = File(entity.path);
      final parts = file.uri.pathSegments;
      final n = parts.length;
      if (n >= 5 &&
          parts[n - 2] == 'l10n' &&
          parts[n - 3] == 'src' &&
          parts[n - 4] == 'lib') {
        // Keyed by the package directory (full path), not its name.
        sets
            .putIfAbsent(file.parent.parent.parent.parent.path, () => [])
            .add(file);
      }
    }
  }
}

List<String> _checkPackage(
  String pkgDir,
  List<File> files,
  List<String> requiredLocales,
) {
  final pkg = pkgDir.split('/').last;
  final out = <String>[];
  final byLocale = <String, Map<String, Object?>>{};
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    if (!name.startsWith('${pkg}_')) {
      out.add('$pkg: $name does not start with "${pkg}_"');
      continue;
    }
    final locale = name.substring(pkg.length + 1, name.length - '.arb'.length);
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      out.add('$pkg: $name is not valid JSON (${e.message})');
      continue;
    } on FileSystemException catch (e) {
      out.add('$pkg: cannot read $name (${e.message})');
      continue;
    }
    if (decoded is! Map<String, Object?>) {
      out.add('$pkg: $name is not a JSON object');
      continue;
    }
    final declared = decoded['@@locale'];
    if (declared != locale) {
      out.add('$pkg: $name has @@locale "$declared", expected "$locale"');
    }
    byLocale[locale] = decoded;
  }

  final template = byLocale['en'];
  if (template == null) {
    out.add('$pkg: missing template ${pkg}_en.arb (locale en)');
  }
  for (final locale in requiredLocales) {
    if (!byLocale.containsKey(locale) &&
        !(locale == 'en' && template == null)) {
      out.add('$pkg: missing locale $locale (expected ${pkg}_$locale.arb)');
    }
  }
  if (template == null) {
    return out;
  }

  final templateKeys = _messageKeys(template);
  for (final entry in byLocale.entries) {
    if (entry.key == 'en') {
      continue;
    }
    final keys = _messageKeys(entry.value);
    for (final key in templateKeys.difference(keys)) {
      out.add('$pkg: locale ${entry.key} is missing key $key');
    }
    for (final key in keys.difference(templateKeys)) {
      out.add('$pkg: locale ${entry.key} has unknown key $key');
    }
  }
  return out;
}

Set<String> _messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();
