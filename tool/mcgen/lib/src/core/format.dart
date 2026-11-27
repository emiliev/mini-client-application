// Formatting with the pinned SDK's own `dart format` (F-0065).
//
// mcgen does not link package:dart_style: the offline pub cache has no
// 3.1.13, the version Dart 3.13.5 bundles, and a different patch release can
// format differently from tool/checks/lib/format_gate.sh. Instead it runs the
// `dart` that runs mcgen (the FVM pin, under `fvm dart run`) once per gen,
// over a scratch copy of the Dart files, with the repo's settings given on
// the command line: language version, `trailing_commas: preserve`, page
// width. Nothing about the scratch location reaches the output.

import 'dart:io';

import 'package:mcgen/src/core/config.dart';
import 'package:path/path.dart' as p;

class FormatError implements Exception {
  FormatError(this.message);

  final String message;

  @override
  String toString() => message;
}

class DartFormatter {
  DartFormatter(this.config, {String? dartExecutable})
    : dart = dartExecutable ?? Platform.resolvedExecutable;

  final McgenConfig config;

  /// The `dart` executable.
  final String dart;

  String? _version;

  /// `dart format --version` of [dart].
  String get version => _version ??= () {
    final r = Process.runSync(dart, ['format', '--version']);
    if (r.exitCode != 0) {
      throw FormatError('`$dart format --version` failed: ${r.stderr}');
    }
    return (r.stdout as String).trim();
  }();

  /// Throws unless [version] is the pinned formatter.
  void checkPinned() {
    if (version != config.formatterVersion) {
      throw FormatError(
        'dart format is $version, but tool/mcgen/mcgen.yaml pins ${config.formatterVersion}; '
        'run mcgen with the FVM-pinned SDK (`fvm dart run tool/mcgen`)',
      );
    }
  }

  /// Formats [files] (module-relative path -> source) in one process.
  Map<String, String> formatAll(Map<String, String> files) {
    if (files.isEmpty) return const {};
    checkPinned();
    final scratch = Directory.systemTemp.createTempSync('mcgen-format-');
    try {
      // Shields the scratch tree from any analysis_options.yaml above it.
      File(p.join(scratch.path, 'analysis_options.yaml')).writeAsStringSync(
        'formatter:\n  trailing_commas: preserve\n  page_width: ${config.pageWidth}\n',
      );
      files.forEach((path, source) {
        final f = File(p.join(scratch.path, 'src', path));
        f.parent.createSync(recursive: true);
        f.writeAsStringSync(source);
      });
      final r = Process.runSync(dart, [
        'format',
        '--language-version=${config.languageVersion}',
        '--trailing-commas=preserve',
        '--page-width=${config.pageWidth}',
        '--show=none',
        '--summary=none',
        p.join(scratch.path, 'src'),
      ]);
      if (r.exitCode != 0) {
        final prefix = '${p.join(scratch.path, 'src')}${p.separator}';
        final msg = '${r.stderr}${r.stdout}'.replaceAll(prefix, '');
        throw FormatError('dart format failed on generated code:\n$msg');
      }
      return {
        for (final path in files.keys)
          path: File(p.join(scratch.path, 'src', path)).readAsStringSync(),
      };
    } finally {
      scratch.deleteSync(recursive: true);
    }
  }
}
