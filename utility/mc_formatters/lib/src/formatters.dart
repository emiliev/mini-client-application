import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:mc_formatters/src/money.dart';

/// Loads the date symbols for every locale. Call once at start-up (and in
/// tests) before [formatDate]; number formats need no initialisation.
Future<void> initializeFormatters() => initializeDateFormatting();

/// Formats [money] for [locale]: `19,99 €` in `de`, `€19.99` in `en`.
String formatMoney(Money money, String locale) => NumberFormat.simpleCurrency(
  locale: locale,
  name: money.currency.code,
  decimalDigits: money.currency.fractionDigits,
).format(money.majorUnits);

/// Formats [date] as a medium date (`Nov 24, 2026` / `24. Nov. 2026`).
/// Requires [initializeFormatters].
String formatDate(DateTime date, String locale) =>
    DateFormat.yMMMd(locale).format(date);

/// Formats [date] as a short date and time in the locale's clock style (12 h
/// in `en`, 24 h in `de`). Requires [initializeFormatters].
String formatDateTime(DateTime date, String locale) =>
    DateFormat.yMd(locale).add_jm().format(date);

/// Compact number: `1.2K` in `en`.
String formatCompact(num value, String locale) =>
    NumberFormat.compact(locale: locale).format(value);

/// Plain decimal number with the locale's separators.
String formatNumber(num value, String locale) =>
    NumberFormat.decimalPattern(locale).format(value);
