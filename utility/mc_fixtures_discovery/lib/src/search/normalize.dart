/// Text folding for matching: case and diacritics are ignored.
library;

/// Latin letters with marks, grouped by the text they fold to. [foldText]
/// lower-cases first, so only lower-case forms are listed.
const Map<String, String> _folds = {
  'a': 'àáâãäåāăąǎ',
  'c': 'çćĉċč',
  'd': 'ďđ',
  'e': 'èéêëēĕėęě',
  'g': 'ĝğġģ',
  'h': 'ĥħ',
  'i': 'ìíîïĩīĭįı',
  'j': 'ĵ',
  'k': 'ķ',
  'l': 'ĺļľŀł',
  'n': 'ñńņňŉ',
  'o': 'òóôõöøōŏőǒ',
  'r': 'ŕŗř',
  's': 'śŝşš',
  't': 'ţťŧ',
  'u': 'ùúûüũūŭůűųǔ',
  'w': 'ŵ',
  'y': 'ýÿŷ',
  'z': 'źżž',
  'ss': 'ß',
  'ae': 'æ',
  'oe': 'œ',
};

final Map<int, String> _foldTable = {
  for (final entry in _folds.entries)
    for (final rune in entry.value.runes) rune: entry.key,
};

/// Combining marks (U+0300 to U+036F): what a decomposed accent leaves.
bool _isCombining(int rune) => rune >= 0x300 && rune <= 0x36f;

/// [text] in lower case, without diacritics, with each run of whitespace as
/// one space and no leading or trailing space.
String foldText(String text) {
  final out = StringBuffer();
  var space = false;
  for (final rune in text.toLowerCase().runes) {
    if (_isCombining(rune)) {
      continue;
    }
    final char = String.fromCharCode(rune);
    if (char.trim().isEmpty) {
      space = true;
      continue;
    }
    if (space && out.isNotEmpty) {
      out.write(' ');
    }
    space = false;
    out.write(_foldTable[rune] ?? char);
  }
  return out.toString();
}
