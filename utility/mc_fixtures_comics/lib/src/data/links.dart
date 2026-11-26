/// The ID contract with the other fixture domains (T-0038). The comics
/// package must stay pure Dart, so it cannot import `mc_fixtures_media`
/// (Flutter). It states what it relies on here instead, and the
/// provider-contract test checks every constant against the real packages: a
/// drift fails a test, not a user. Since T-0041 `mc_fixtures_characters` is
/// pure Dart and the detail's cast summary reads it directly.
library;

/// The first character id in `mc_fixtures_characters` (`idBase`).
const int characterIdBase = 100000;

/// How many characters `mc_fixtures_characters` serves (`characterCount`).
const int characterIdCount = 1500;

/// The bundled art set covers come from (`placeholderSets` in
/// `mc_fixtures_media`) and how many images it holds. Comics reuse the
/// characters placeholders: they are generated, original and trademark-free.
const String coverImageSet = 'characters';
const int coverImageCount = 24;
