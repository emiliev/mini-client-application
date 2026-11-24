import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:mc_paging/mc_paging.dart';
import 'package:test/test.dart';

/// A clock the test advances by hand; no real timers run.
class _FakeClock {
  Duration now = Duration.zero;
  final _timers = <_FakeTimer>[];

  Timer start(Duration delay, void Function() run) {
    final timer = _FakeTimer(now + delay, run);
    _timers.add(timer);
    return timer;
  }

  void advance(Duration by) {
    now += by;
    for (final t in _timers.toList()) {
      if (t.isActive && t.dueAt <= now) {
        t.fire();
      }
    }
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.dueAt, this._run);

  final Duration dueAt;
  final void Function() _run;
  bool _active = true;

  void fire() {
    _active = false;
    _run();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

void main() {
  late _FakeClock clock;
  late List<String> searches;
  late int clears;
  late DebouncedQuery sut;

  setUp(() {
    clock = _FakeClock();
    searches = [];
    clears = 0;
    sut = DebouncedQuery(
      onSearch: searches.add,
      onClear: () => clears++,
      timerFactory: clock.start,
    );
  });

  test(
    'T-0030-AC4: 5 characters in 200 ms fire one search with the final text',
    () {
      for (final text in ['t', 'th', 'tho', 'thor', 'thor!']) {
        sut.update(text);
        clock.advance(const Duration(milliseconds: 40));
      }
      expect(searches, isEmpty);

      clock.advance(const Duration(milliseconds: 300));

      expect(searches, ['thor!']);
      expect(clears, 0);
    },
  );

  test('T-0030-AC4: nothing fires before the delay has passed', () {
    sut.update('hulk');

    clock.advance(const Duration(milliseconds: 299));
    expect(searches, isEmpty);
    clock.advance(const Duration(milliseconds: 1));

    expect(searches, ['hulk']);
  });

  test('T-0030-AC4: a blank query after a non-empty one clears', () {
    sut.update('hulk');
    clock.advance(const Duration(milliseconds: 300));

    sut.update('   ');
    clock.advance(const Duration(seconds: 1));

    expect(searches, ['hulk']);
    expect(clears, 1);
  });

  test(
    'T-0030-AC4: deleting text while a search is pending cancels it, no clear',
    () {
      sut.update('h');

      sut.update('');
      clock.advance(const Duration(seconds: 1));

      expect(searches, isEmpty);
      expect(clears, 0);
    },
  );

  test('T-0030-AC4: a blank query with no earlier query does nothing', () {
    sut.update('');
    sut.update('  ');
    clock.advance(const Duration(seconds: 1));

    expect(searches, isEmpty);
    expect(clears, 0);
  });

  test('T-0030-AC4: the searched text is trimmed', () {
    sut.update('  thor ');
    clock.advance(const Duration(milliseconds: 300));

    expect(searches, ['thor']);
  });

  test('T-0030-AC4: dispose cancels a pending search', () {
    sut.update('thor');

    sut.dispose();
    clock.advance(const Duration(seconds: 1));

    expect(searches, isEmpty);
  });

  test('T-0030-AC4: an unchanged trimmed query does not search again', () {
    sut.update('thor');
    clock.advance(const Duration(milliseconds: 300));

    sut.update('thor ');
    clock.advance(const Duration(seconds: 1));

    expect(searches, ['thor']);
  });

  test('T-0030-AC4: the same query is searched again after a clear', () {
    sut.update('thor');
    clock.advance(const Duration(milliseconds: 300));
    sut.update('');

    sut.update('thor');
    clock.advance(const Duration(milliseconds: 300));

    expect(searches, ['thor', 'thor']);
    expect(clears, 1);
  });

  test('T-0030-AC4: update after dispose does nothing', () {
    sut.dispose();

    sut.update('thor');
    clock.advance(const Duration(seconds: 1));

    expect(searches, isEmpty);
    expect(clears, 0);
  });

  test('T-0030-AC4: the default timer fires after the delay (fake async)', () {
    fakeAsync((async) {
      final found = <String>[];
      final sut = DebouncedQuery(onSearch: found.add, onClear: () {});

      sut.update('loki');
      async.elapse(const Duration(milliseconds: 299));
      expect(found, isEmpty);
      async.elapse(const Duration(milliseconds: 1));

      expect(found, ['loki']);
    });
  });
}
