/// What a sink receives: one delivered entry, numbered within its session.
///
/// [sessionId] is the session the entry was tracked in. [seq] counts the
/// entries delivered in that session, from 1, with no gaps.
sealed class AnalyticsRecord {
  const AnalyticsRecord({required this.sessionId, required this.seq});

  final String sessionId;
  final int seq;
}

/// A tracked event (also a screen view, `mc_screen_view`, and the kit's
/// `mc_session_start`).
class AnalyticsEventRecord extends AnalyticsRecord {
  const AnalyticsEventRecord({
    required this.name,
    required this.params,
    required super.sessionId,
    required super.seq,
  });

  final String name;
  final Map<String, Object> params;

  @override
  String toString() => 'AnalyticsEventRecord($sessionId #$seq $name $params)';
}

/// A user property set with `Analytics.setUserProperty`.
class AnalyticsUserPropertyRecord extends AnalyticsRecord {
  const AnalyticsUserPropertyRecord({
    required this.key,
    required this.value,
    required super.sessionId,
    required super.seq,
  });

  final String key;
  final Object value;

  @override
  String toString() =>
      'AnalyticsUserPropertyRecord($sessionId #$seq $key=$value)';
}
