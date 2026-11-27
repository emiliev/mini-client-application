/// Whether the user allows analytics (P1-05 AC4).
///
/// [unknown] is the state before the user chose: events are buffered in
/// memory and nothing reaches a sink. [granted] delivers. [denied] discards.
enum AnalyticsConsent {
  unknown,
  granted,
  denied;

  /// The consent named [value] (`unknown`, `granted` or `denied`), or
  /// [unknown] for anything else. Unrecognised input never grants.
  static AnalyticsConsent parse(Object? value) {
    for (final consent in values) {
      if (consent.name == value) {
        return consent;
      }
    }
    return unknown;
  }
}
