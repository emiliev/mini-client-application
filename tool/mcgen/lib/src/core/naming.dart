// Name conversions emitters share.

/// `ReadingListEditor` / `readingList` -> `reading_list_editor` / `reading_list`.
String snakeCase(String name) => name
    .replaceAllMapped(RegExp(r'(?<=[a-z0-9])([A-Z])'), (m) => '_${m[1]}')
    .replaceAllMapped(RegExp(r'(?<=[A-Z])([A-Z])(?=[a-z])'), (m) => '_${m[1]}')
    .toLowerCase();

/// `reading_list` / `ReadingList` -> `ReadingList`.
String pascalCase(String name) {
  if (!name.contains('_')) {
    return name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}';
  }
  return name
      .split('_')
      .where((s) => s.isNotEmpty)
      .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
      .join();
}

/// `ReadingList` / `reading_list` -> `readingList`.
String camelCase(String name) {
  final pc = pascalCase(name);
  return pc.isEmpty ? pc : '${pc[0].toLowerCase()}${pc.substring(1)}';
}

/// A Dart single-quoted string literal for [text].
String dartString(String text) {
  final escaped = text
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n');
  return "'$escaped'";
}
