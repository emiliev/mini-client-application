import 'dart:io';

import 'package:args/args.dart';
import 'package:loc/loc.dart';

Never _usage(ArgParser p, [String? err]) {
  if (err != null) stderr.writeln(err);
  stderr.writeln('Usage: loc <root> [options]\n${p.usage}');
  exit(err == null ? 0 : 64);
}

void main(List<String> args) {
  final parser = ArgParser()
    ..addOption('json', help: 'Write mc-loc/1 JSON to this path.')
    ..addOption('md', help: 'Write the Markdown report to this path.')
    ..addOption(
      'generated-root',
      help: 'Scan this tree as the generated bucket.',
    )
    ..addOption('stamp', help: 'Optional stamp recorded in the JSON.')
    ..addOption('commit', help: 'Commit sha to record (default: git HEAD).')
    ..addFlag(
      'strict',
      negatable: false,
      help: 'Fail on committed generated files (D7).',
    )
    ..addFlag(
      'include-untracked',
      negatable: false,
      help: 'Also count files git does not track (default: tracked only).',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults r;
  try {
    r = parser.parse(args);
  } on FormatException catch (e) {
    _usage(parser, e.message);
  }
  if (r['help'] as bool) _usage(parser);
  if (r.rest.length != 1) _usage(parser, 'Expected exactly one <root>.');

  final result = runLoc(
    LocOptions(
      root: r.rest.single,
      generatedRoot: r['generated-root'] as String?,
      strict: r['strict'] as bool,
      stamp: r['stamp'] as String?,
      commit: r['commit'] as String?,
      includeUntracked: r['include-untracked'] as bool,
    ),
  );
  final jsonOut = r['json'] as String?;
  final mdOut = r['md'] as String?;
  final json = encodeJson(result.json);
  if (jsonOut != null) {
    File(jsonOut)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(json);
  }
  if (mdOut != null) {
    File(mdOut)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(result.markdown);
  }
  if (jsonOut == null && mdOut == null) stdout.write(result.markdown);
  for (final w in result.warnings) {
    stderr.writeln('WARN: $w');
  }
  for (final f in result.failures) {
    stderr.writeln('FAIL: $f');
  }
  exit(result.failures.isEmpty ? 0 : 1);
}
