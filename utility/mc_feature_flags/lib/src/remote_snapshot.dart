/// What one successful `GET /v1/flags` said, for one user.
///
/// Flag values stay raw: a value's type is checked when the flag that reads it
/// is evaluated, because only the flag knows what it expects. Experiments are
/// checked here: an entry with a malformed variant is kept as `null` so the
/// evaluation can report it and fall to the next source.
final class RemoteSnapshot {
  const RemoteSnapshot._(this.userId, this.body, this.flags, this.experiments);

  /// Parses a response (or a cached copy of one) fetched for [userId], null
  /// when anonymous. Throws a [FormatException] when the body is not
  /// `{"flags": {...}, ...}`. Unknown keys and malformed `experiments`
  /// entries never fail the whole body.
  factory RemoteSnapshot.parse(Object? body, String? userId) {
    if (body is! Map || body['flags'] is! Map) {
      throw FormatException('Not a flags body: $body');
    }
    final flags = <String, Object?>{
      for (final entry in (body['flags']! as Map).entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
    final experiments = <String, Map<String, int>?>{};
    final raw = body['experiments'];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is Map && entry['key'] is String) {
          experiments[entry['key'] as String] = _weights(entry['variants']);
        }
      }
    }
    return RemoteSnapshot._(
      userId,
      Map<String, Object?>.unmodifiable({
        'flags': flags,
        'experiments': raw is List
            ? List<Object?>.unmodifiable(raw)
            : <Object?>[],
      }),
      Map.unmodifiable(flags),
      Map.unmodifiable(experiments),
    );
  }

  /// The cache entry [toJson] wrote, or null for anything else (corrupt,
  /// another shape, another user than [forUser]).
  static RemoteSnapshot? fromCache(Object? json, {required String? forUser}) {
    if (json is! Map || json['userId'] != forUser) {
      return null;
    }
    try {
      return RemoteSnapshot.parse(json['body'], forUser);
    } on FormatException {
      return null;
    }
  }

  /// Who it was fetched for; null for an anonymous fetch.
  final String? userId;

  /// The accepted body, as written to the cache.
  final Map<String, Object?> body;

  /// Flag key -> raw JSON value.
  final Map<String, Object?> flags;

  /// Experiment key -> variant name -> weight, or null when the entry is
  /// malformed (a variant without a name, or a weight that is not a
  /// non-negative integer, or no variants at all).
  final Map<String, Map<String, int>?> experiments;

  /// The cache form: `{"userId": ..., "body": ...}`.
  Map<String, Object?> toJson() => {'userId': userId, 'body': body};

  static Map<String, int>? _weights(Object? variants) {
    if (variants is! List) {
      return null;
    }
    final weights = <String, int>{};
    for (final variant in variants) {
      if (variant is! Map) {
        return null;
      }
      final name = variant['name'];
      final weight = variant['weight'];
      if (name is! String || weight is! int || weight < 0) {
        return null;
      }
      weights[name] = weight;
    }
    return weights;
  }
}
