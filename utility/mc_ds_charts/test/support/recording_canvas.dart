import 'dart:ui';

/// One recorded canvas call.
class Call {
  Call(this.name, this.args);

  /// The method name, e.g. `drawRect`.
  final String name;
  final List<Object?> args;

  T arg<T>(int i) => args[i] as T;

  @override
  String toString() => '$name($args)';
}

/// A [Canvas] that records every call instead of drawing, so painter tests can
/// assert the exact rects, lines, arcs and paths a painter produces.
class RecordingCanvas implements Canvas {
  final List<Call> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString().replaceAllMapped(
      RegExp(r'Symbol\("(.*)"\)'),
      (m) => m.group(1)!,
    );
    calls.add(Call(name, invocation.positionalArguments));
    return null;
  }

  Iterable<Call> named(String name) => calls.where((c) => c.name == name);

  /// `drawRect` calls whose paint is a fill (not a stroke).
  List<Rect> fillRects() => [
    for (final c in named('drawRect'))
      if (c.arg<Paint>(1).style == PaintingStyle.fill) c.arg<Rect>(0),
  ];

  /// Fill rects together with their colours.
  List<(Rect, Color)> filledRects() => [
    for (final c in named('drawRect'))
      if (c.arg<Paint>(1).style == PaintingStyle.fill)
        (c.arg<Rect>(0), c.arg<Paint>(1).color),
  ];

  /// `drawLine` calls as (from, to, paint).
  List<(Offset, Offset, Paint)> lines() => [
    for (final c in named('drawLine'))
      (c.arg<Offset>(0), c.arg<Offset>(1), c.arg<Paint>(2)),
  ];

  /// `drawArc` calls as (rect, start, sweep, paint).
  List<(Rect, double, double, Paint)> arcs() => [
    for (final c in named('drawArc'))
      (c.arg<Rect>(0), c.arg<double>(1), c.arg<double>(2), c.arg<Paint>(4)),
  ];

  int get textCount => named('drawParagraph').length;
}
