import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mc_analytics/src/consent.dart';
import 'package:mc_analytics/src/event.dart';
import 'package:mc_analytics/src/records.dart';
import 'package:mc_analytics/src/sinks.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// The current time. Injected, so a test moves it by hand.
typedef AnalyticsClock = DateTime Function();

/// Saves a consent choice (the DI initializer passes `ConsentStore.save`).
typedef ConsentPersister = Future<void> Function(AnalyticsConsent consent);

/// While consent is `unknown`, at most this many entries are buffered; the
/// oldest is dropped first.
const int analyticsBufferLimit = 100;

/// A session ends after this long in the background.
const Duration analyticsSessionTimeout = Duration(minutes: 30);

/// The tracking facade (plan 01 U06): typed events, a consent gate, app
/// sessions and fan-out to [AnalyticsSink]s. No third-party SDK.
///
/// **The gate.** Nothing reaches a sink unless consent is `granted` at the
/// moment of delivery. With `unknown`, entries wait in a buffer of
/// [analyticsBufferLimit]; `granted` flushes it in order, `denied` discards
/// it. With `denied`, an entry is dropped when it is tracked.
///
/// **Delivery is a microtask later.** `track`, `screen` and `setUserProperty`
/// never call a sink inline: they queue the entry, and one microtask later
/// the queue is drained, re-reading consent for every entry. So a switch to
/// `denied` stops everything queued before it in the same turn, and
/// [setConsent] changes the state synchronously (the persisting is what is
/// asynchronous). Tests await a microtask (`await Future<void>.value()`)
/// before asserting on a sink.
///
/// **Sessions.** A cold start is a new session, and so is [reset], and so is
/// coming back to the foreground after 30 minutes in the background. Each
/// delivered entry carries its session's id and a `seq` counted in delivery
/// order from 1.
///
/// **Blocs** track through the pure-Dart port [AnalyticsTracker]
/// (`mc_monitoring`), which this class implements and the DI initializer
/// registers: a bloc may not import this Flutter package (R15, T-0056).
class Analytics implements AnalyticsTracker {
  Analytics({
    required List<AnalyticsSink> sinks,
    required Monitoring monitoring,
    AnalyticsConsent consent = AnalyticsConsent.unknown,
    ConsentPersister? persist,
    Random? random,
    AnalyticsClock? clock,
    bool? debugMode,
  }) : _sinks = List.of(sinks),
       _monitoring = monitoring,
       _consent = consent,
       _persist = persist,
       _random = random ?? Random.secure(),
       _clock = clock ?? DateTime.now,
       _debugMode = debugMode ?? kDebugMode {
    _startSession('cold_start');
  }

  final List<AnalyticsSink> _sinks;
  final Monitoring _monitoring;
  final ConsentPersister? _persist;
  final Random _random;
  final AnalyticsClock _clock;
  final bool _debugMode;

  AnalyticsConsent _consent;
  final StreamController<AnalyticsConsent> _changes =
      StreamController<AnalyticsConsent>.broadcast();
  final Queue<_Pending> _pending = Queue<_Pending>();
  final Map<String, int> _seqs = <String, int>{};
  final Set<AnalyticsSink> _failedSinks = Set<AnalyticsSink>.identity();
  bool _drainScheduled = false;
  bool _disposed = false;

  late String _sessionId;
  DateTime? _backgroundedAt;

  int _dropped = 0;
  int _droppedInPeriod = 0;
  int _reportedInPeriod = 0;

  /// The current consent.
  AnalyticsConsent get consent => _consent;

  /// Every change of consent, for the settings screen. A repeated value
  /// emits nothing.
  Stream<AnalyticsConsent> get consentChanges => _changes.stream;

  /// The current session's id.
  String get sessionId => _sessionId;

  /// Entries waiting for consent (or for the next microtask).
  int get bufferedCount => _pending.length;

  /// Entries dropped for want of room in the buffer, since the start.
  int get droppedCount => _dropped;

  /// Adds a sink for later entries. For tests and e2e, which attach a
  /// recorder to the running app; the gate still stands in front of it.
  void addSink(AnalyticsSink sink) => _sinks.add(sink);

  void removeSink(AnalyticsSink sink) => _sinks.remove(sink);

  /// Tracks [event]. An invalid event throws an [AssertionError] in debug
  /// mode and is dropped and reported to monitoring (once) otherwise.
  void track(AnalyticsEvent event) {
    if (_disposed) {
      return;
    }
    final violations = AnalyticsRules.validateEvent(event.name, event.params);
    if (violations.isNotEmpty) {
      _reject('event "${event.name}"', violations);
      return;
    }
    _enqueueEvent(event.name, event.params);
  }

  /// [track] for the bloc-facing port: the same validation, gate and
  /// session as an [AnalyticsEvent] named [name] with [params].
  @override
  void trackEvent(String name, [Map<String, Object> params = const {}]) =>
      track(AnalyticsEvent(name, params: params));

  /// Tracks that screen [name] (snake_case) is showing, as the kit's
  /// `mc_screen_view` with the param `screen_name`.
  void screen(String name, {Map<String, Object> params = const {}}) {
    if (_disposed) {
      return;
    }
    final violations = [
      ...AnalyticsRules.validateName(name, allowReserved: true),
      ...AnalyticsRules.validateEvent('screen_view', params),
      // The kit adds `screen_name`, which counts towards the cap.
      if (params.length + 1 > AnalyticsRules.maxParams)
        AnalyticsViolation(
          AnalyticsViolationKind.tooManyParams,
          '${params.length} params and screen_name '
          '(max ${AnalyticsRules.maxParams} with screen_name)',
        ),
    ];
    if (violations.isNotEmpty) {
      _reject('screen "$name"', violations);
      return;
    }
    _enqueueEvent(screenViewEventName, {...params, 'screen_name': name});
  }

  /// Sets the user property [key] to [value] (`String`, `int`, `double` or
  /// `bool`), with the same validation as an event.
  void setUserProperty(String key, Object value) {
    if (_disposed) {
      return;
    }
    final violations = [
      ...AnalyticsRules.validateName(key),
      ...AnalyticsRules.validateValue('value', value),
    ];
    if (violations.isNotEmpty) {
      _reject('user property "$key"', violations);
      return;
    }
    final sessionId = _sessionId;
    _enqueue(
      _Pending(
        sessionId,
        (seq) => AnalyticsUserPropertyRecord(
          key: key,
          value: value,
          sessionId: sessionId,
          seq: seq,
        ),
      ),
    );
  }

  /// Sign-out: starts a new session (so the next entries cannot be tied to the
  /// user who left). The caller decides when; consent stays. A sink that keeps
  /// user properties should clear them when it sees `mc_session_start` with
  /// `reason` `reset`.
  ///
  /// What was tracked before the reset is kept as it was: entries already
  /// queued for delivery (consent granted) go out under their own session id
  /// and `seq`, so `track(signed_out); reset();` still reports `signed_out`.
  /// Only the buffer that waits for a consent choice (consent `unknown`) is
  /// dropped, because it holds a signed-out user's activity that nobody has
  /// agreed to send yet. With `denied` nothing is queued.
  void reset() {
    if (_disposed) {
      return;
    }
    if (_consent == AnalyticsConsent.unknown) {
      _pending.clear();
    }
    _startSession('reset');
  }

  /// Chooses [next]. The state changes **now**: the buffer is flushed
  /// (`granted`) or discarded (`denied`) and later entries follow the new
  /// choice. The returned future completes once the choice is saved; a failed
  /// save is reported to monitoring and does not undo the choice.
  Future<void> setConsent(AnalyticsConsent next) {
    if (_disposed) {
      return Future<void>.value();
    }
    final previous = _consent;
    _consent = next;
    if (previous != next) {
      if (previous == AnalyticsConsent.unknown) {
        _closeBufferPeriod();
      }
      switch (next) {
        case AnalyticsConsent.denied:
          _pending.clear();
        case AnalyticsConsent.granted:
          if (_pending.isNotEmpty) {
            _scheduleDrain();
          }
        case AnalyticsConsent.unknown:
          _trimToLimit();
      }
      if (!_disposed) {
        _changes.add(next);
      }
    }
    return _save(next);
  }

  /// The app went to the background (`paused`, `hidden` or `detached`).
  void appBackgrounded() {
    if (!_disposed) {
      _backgroundedAt ??= _clock();
    }
  }

  /// The app came back (`resumed`). After 30 minutes or more in the
  /// background, a new session starts.
  void appForegrounded() {
    if (_disposed) {
      return;
    }
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since != null &&
        _clock().difference(since) >= analyticsSessionTimeout) {
      _startSession('timeout');
    }
  }

  /// After this, `track`, `screen`, `setUserProperty`, `setConsent`, `reset`
  /// and the lifecycle calls do nothing, nothing more is delivered and nothing
  /// is saved.
  void dispose() {
    _disposed = true;
    _pending.clear();
    unawaited(_changes.close());
  }

  // -- internals ------------------------------------------------------------

  Future<void> _save(AnalyticsConsent consent) async {
    final persist = _persist;
    if (persist == null) {
      return;
    }
    try {
      await persist(consent);
    } on Object catch (error, stack) {
      unawaited(_monitoring.recordError(error, stack));
    }
  }

  void _reject(String what, List<AnalyticsViolation> violations) {
    final error = AnalyticsValidationError(what, violations);
    if (_debugMode) {
      throw AssertionError(error.toString());
    }
    unawaited(_monitoring.recordError(error, null));
  }

  String _newSessionId() => [
    for (var i = 0; i < 4; i++)
      _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
  ].join();

  void _startSession(String reason) {
    _sessionId = _newSessionId();
    _enqueueEvent(sessionStartEventName, {'reason': reason});
  }

  void _enqueueEvent(String name, Map<String, Object> params) {
    final sessionId = _sessionId;
    final copy = Map<String, Object>.unmodifiable(params);
    _enqueue(
      _Pending(
        sessionId,
        (seq) => AnalyticsEventRecord(
          name: name,
          params: copy,
          sessionId: sessionId,
          seq: seq,
        ),
      ),
    );
  }

  void _enqueue(_Pending entry) {
    switch (_consent) {
      case AnalyticsConsent.denied:
        return;
      case AnalyticsConsent.unknown:
        _pending.add(entry);
        _trimToLimit();
      case AnalyticsConsent.granted:
        _pending.add(entry);
        _scheduleDrain();
    }
  }

  void _trimToLimit() {
    var droppedNow = 0;
    while (_pending.length > analyticsBufferLimit) {
      _pending.removeFirst();
      droppedNow++;
    }
    if (droppedNow == 0) {
      return;
    }
    final first = _droppedInPeriod == 0;
    _dropped += droppedNow;
    _droppedInPeriod += droppedNow;
    if (first) {
      _reportOverflow();
    }
  }

  /// Consent left `unknown`: report what was dropped since the last report.
  void _closeBufferPeriod() {
    if (_droppedInPeriod != _reportedInPeriod) {
      _reportOverflow();
    }
    _droppedInPeriod = 0;
    _reportedInPeriod = 0;
  }

  void _reportOverflow() {
    _reportedInPeriod = _droppedInPeriod;
    unawaited(
      _monitoring.trackEvent(
        'analytics_buffer_overflow',
        attributes: {
          'dropped': _droppedInPeriod,
          'limit': analyticsBufferLimit,
        },
      ),
    );
  }

  void _scheduleDrain() {
    if (_drainScheduled) {
      return;
    }
    _drainScheduled = true;
    scheduleMicrotask(_drain);
  }

  void _drain() {
    _drainScheduled = false;
    // Consent is read again for every entry: a sink (or anything it calls)
    // may deny in the middle of a flush.
    while (_consent == AnalyticsConsent.granted && _pending.isNotEmpty) {
      final entry = _pending.removeFirst();
      final seq = (_seqs[entry.sessionId] ?? 0) + 1;
      _seqs[entry.sessionId] = seq;
      _deliver(entry.build(seq));
    }
    // A session's counter is only needed while it can still deliver.
    _seqs.removeWhere(
      (id, _) => id != _sessionId && !_pending.any((e) => e.sessionId == id),
    );
  }

  void _deliver(AnalyticsRecord record) {
    for (final sink in List.of(_sinks)) {
      try {
        sink.record(record);
      } on Object catch (error, stack) {
        if (_failedSinks.add(sink)) {
          unawaited(_monitoring.recordError(error, stack));
        }
      }
    }
  }
}

/// A queued entry. The session is fixed when it is tracked; the `seq` is
/// given when it is delivered, so dropped entries leave no gap.
class _Pending {
  _Pending(this.sessionId, this.build);

  final String sessionId;
  final AnalyticsRecord Function(int seq) build;
}
