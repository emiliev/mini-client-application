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
/// Returns one message per violation; empty means the check passed.
List<String> checkL10n(
  String root, {
  List<String> requiredLocales = defaultRequiredLocales,
}) {
  final violations = <String>[];
  final sets = <String, List<File>>{};
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.arb')) {
      continue;
    }
    final parts = entity.uri.pathSegments;
    final n = parts.length;
    if (n < 5 ||
        parts[n - 2] != 'l10n' ||
        parts[n - 3] != 'src' ||
        parts[n - 4] != 'lib') {
      continue;
    }
    if (parts.contains('.dart_tool') || parts.contains('bazel-out')) {
      continue;
    }
    sets.putIfAbsent(parts[n - 5], () => []).add(entity);
  }

  for (final entry in sets.entries) {
    violations.addAll(_checkPackage(entry.key, entry.value, requiredLocales));
  }
  violations.sort();
  return violations;
}

List<String> _checkPackage(
  String pkg,
  List<File> files,
  List<String> requiredLocales,
) {
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
