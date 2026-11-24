import 'dart:ui' show Locale;

import 'package:flutter/widgets.dart' show LocalizationsDelegate;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:mc_l10n_core/src/l10n/mc_l10n_core_l10n.dart';

/// Pseudo-locale used by l10n tests (R24). Never offered in release builds.
const Locale mcPseudoLocale = Locale('en', 'XA');

/// Locales the app ships with.
const List<Locale> mcReleaseLocales = [Locale('en'), Locale('de')];

/// Locales for l10n tests: the release locales plus [mcPseudoLocale].
const List<Locale> mcTestLocales = [...mcReleaseLocales, mcPseudoLocale];

/// Delegates an app (or a flow) installs: the core strings plus the Flutter
/// framework's own.
const List<LocalizationsDelegate<Object?>> mcLocalizationsDelegates = [
  McL10nCoreL10n.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// `supportedLocales` for a `MaterialApp`. The pseudo-locale is included only
/// when [includePseudo] is set (tests).
///
/// Apps must use this, not the generated `McL10nCoreL10n.supportedLocales`,
/// which lists `en_XA` too (R24).
List<Locale> mcSupportedLocales({bool includePseudo = false}) =>
    includePseudo ? mcTestLocales : mcReleaseLocales;
