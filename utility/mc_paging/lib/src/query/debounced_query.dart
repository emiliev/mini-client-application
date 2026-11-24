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
  bool _disposed = false;

  /// The query [onSearch] last fired for; null after a clear.
  String? _searched;

  /// The field's current text. A query equal to the one last searched does
  /// not search again. A blank text clears only when a search actually fired
  /// for the previous query, so typing and deleting within the delay emits
  /// nothing. Does nothing after [dispose].
  void update(String text) {
    if (_disposed) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    final query = text.trim();
    if (query.isEmpty) {
      if (_searched != null) {
        _searched = null;
        onClear();
      }
      return;
    }
    if (query == _searched) {
      return;
    }
    _timer = _timerFactory(delay, () {
      _timer = null;
      _searched = query;
      onSearch(query);
    });
  }

  /// Cancels a pending search and ignores later updates.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
