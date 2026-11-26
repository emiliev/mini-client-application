/// Text folding for matching: case and diacritics are ignored.
library;

/// Latin letters with marks, grouped by the text they fold to. Dart has no
/// built-in NFD, so this table is the whole story: Latin-1, Latin Extended-A,
/// comma-below ș and ț, the Vietnamese letters and Latin Extended Additional
/// (U+1E00 to U+1EFF). Combining marks are dropped as well, so a decomposed
/// accent folds like a composed one. [foldText] lower-cases first, so only
/// lower-case forms are listed.
const Map<String, String> _folds = {
  'a': 'àáâãäåāăąǎạảấầẩẫậắằẳẵặḁẚ',
  'b': 'ḃḅḇ',
  'c': 'çćĉċčḉ',
  'd': 'ďđḋḍḏḑḓ',
  'e': 'èéêëēĕėęěẹẻẽếềểễệḕḗḙḛḝ',
  'f': 'ḟ',
  'g': 'ĝğġģḡ',
  'h': 'ĥħḣḥḧḩḫẖ',
  'i': 'ìíîïĩīĭįıỉịḭḯ',
  'j': 'ĵ',
  'k': 'ķḱḳḵ',
  'l': 'ĺļľŀłḷḹḻḽ',
  'm': 'ḿṁṃ',
  'n': 'ñńņňŉṅṇṉṋ',
  'o': 'òóôõöøōŏőǒơọỏốồổỗộớờởỡợṍṏṑṓ',
  'p': 'ṕṗ',
  'r': 'ŕŗřṙṛṝṟ',
  's': 'śŝşšșṡṣṥṧṩ',
  't': 'ţťŧțṫṭṯṱẗ',
  'u': 'ùúûüũūŭůűųǔưụủứừửữựṳṵṷṹṻ',
  'v': 'ṽṿ',
  'w': 'ŵẁẃẅẇẉẘ',
  'x': 'ẋẍ',
  'y': 'ýÿŷỳỵỷỹẏẙ',
  'z': 'źżžẑẓẕ',
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
