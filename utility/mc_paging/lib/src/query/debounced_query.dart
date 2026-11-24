import 'dart:async';

/// Starts a timer. Tests pass a fake so no real time passes.
typedef TimerFactory = Timer Function(Duration delay, void Function() run);

Timer _realTimer(Duration delay, void Function() run) => Timer(delay, run);

/// Turns keystrokes into searches: waits until typing pauses for [delay],
/// then reports the final text once. Text that is empty after trimming
/// cancels a pending search and, if there was a query, reports a clear.
final class DebouncedQuery {
  DebouncedQuery({
    required this.onSearch,
    required this.onClear,
    this.delay = const Duration(milliseconds: 300),
    TimerFactory? timerFactory,
  }) : _timerFactory = timerFactory ?? _realTimer;

  /// Called with the trimmed text once typing pauses.
  final void Function(String query) onSearch;

  /// Called when the text becomes empty after a non-empty query.
  final void Function() onClear;

  final Duration delay;
  final TimerFactory _timerFactory;

  Timer? _timer;
  bool _hasQuery = false;

  /// The field's current text.
  void update(String text) {
    _timer?.cancel();
    _timer = null;
    final query = text.trim();
    if (query.isEmpty) {
      if (_hasQuery) {
        _hasQuery = false;
        onClear();
      }
      return;
    }
    _hasQuery = true;
    _timer = _timerFactory(delay, () {
      _timer = null;
      onSearch(query);
    });
  }

  /// Cancels a pending search.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
