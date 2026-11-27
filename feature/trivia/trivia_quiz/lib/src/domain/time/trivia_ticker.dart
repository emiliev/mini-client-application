import 'dart:async';

/// The quiz's time: a monotonic millisecond clock the app passes in, and
/// the timers the play bloc runs on it (ADR-0014). Pure Dart.
///
/// The app passes a `Stopwatch`'s reading (chronicle_wiring); a feature test
/// passes the fake clock of the widget-test binding, whose `Timer`s are fake
/// too, so `tester.pump(d)` moves both together and a question's elapsed
/// time is exact to the millisecond. Provided by the flow (`provide:`), so it
/// is not a root import.
final class TriviaTicker {
  const TriviaTicker(this.now);

  /// Milliseconds since an arbitrary origin; never goes back.
  final int Function() now;

  /// How often the countdown is redrawn while a question is asked.
  static const Duration frame = Duration(milliseconds: 100);

  /// Calls [onTick] every [period] until the timer is cancelled.
  Timer every(Duration period, void Function() onTick) =>
      Timer.periodic(period, (_) => onTick());

  /// Calls [onDue] once, after [delay].
  Timer after(Duration delay, void Function() onDue) => Timer(delay, onDue);
}

/// How long the current question has been open, without the time it was
/// paused (in the background, under the quit dialog, covered by another
/// screen).
final class QuestionClock {
  QuestionClock(this._now);

  final int Function() _now;
  int _banked = 0;
  int? _since;

  /// A new question: from 0, running.
  void restart() {
    _banked = 0;
    _since = _now();
  }

  bool get isRunning => _since != null;

  /// Stops counting; the time so far is kept.
  void pause() {
    final since = _since;
    if (since != null) {
      _banked += _now() - since;
      _since = null;
    }
  }

  /// Counts on from where [pause] stopped.
  void resume() => _since ??= _now();

  int get elapsedMs {
    final since = _since;
    return _banked + (since == null ? 0 : _now() - since);
  }
}
