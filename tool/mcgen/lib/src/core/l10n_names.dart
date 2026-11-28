// What gen-l10n reads out of an ARB file name (P-120 (d), F-0066).
//
// flutter_tools' `AppResourceBundle` (packages/flutter_tools/lib/src/
// localizations/gen_l10n_types.dart, Flutter 3.47.7) first tries the whole
// file name as a locale, then the text after each `_` in turn, and takes the
// first that `package:intl`'s `Locale.tryParse` accepts with a language in its
// ISO 639-1 set. `auth_sign_in_en` therefore reads as `in_en`: `in` is the
// deprecated code of Indonesian, `Locale.tryParse` replaces it by `id`, and
// the file's locale becomes `id_EN`, which contradicts its `@@locale`.
//
// mcgen pins intl 0.20.3, the version flutter_tools 3.47.7 resolves, and
// copies the ISO set verbatim; `test/l10n_names_test.dart` checks the copy
// against the pinned SDK's source.

import 'package:intl/locale.dart';

/// `_iso639Languages` of gen_l10n_types.dart (Flutter 3.47.7), in its order.
const _iso639 =
    'aa ab ae af ak am an ar as av ay az ba be bg bh bi bm bn bo br bs '
    'ca ce ch co cr cs cu cv cy da de dv dz ee el en eo es et eu fa ff '
    'fi fil fj fo fr fy ga gd gl gn gsw gu gv ha he hi ho hr ht hu hy '
    'hz ia id ie ig ii ik io is it iu ja jv ka kg ki kj kk kl km kn ko '
    'kr ks ku kv kw ky la lb lg li ln lo lt lu lv mg mh mi mk ml mn mr '
    'ms mt my na nb nd ne ng nl nn no nr nv ny oc oj om or os pa pi pl '
    'ps pt qu rm rn ro ru rw sa sc sd se sg si sk sl sm sn so sq sr ss '
    'st su sv sw ta te tg th ti tk tl tn to tr ts tt tw ty ug uk ur uz '
    've vi vo wa wo xh yi yo za zh zu';

final Set<String> iso639Languages = _iso639.split(' ').toSet();

String? _accepted(String text) {
  final locale = Locale.tryParse(text);
  if (locale == null || !iso639Languages.contains(locale.languageCode)) {
    return null;
  }
  return locale.toLanguageTag().replaceAll('-', '_');
}

/// The locale gen-l10n reads from the ARB file name [stem] (no `.arb`), or
/// null when it reads none.
String? genL10nFileLocale(String stem) {
  final whole = _accepted(stem);
  if (whole != null) return whole;
  for (var i = 0; i < stem.length; i++) {
    if (stem[i] != '_') continue;
    final read = _accepted(stem.substring(i + 1));
    if (read != null) return read;
  }
  return null;
}
