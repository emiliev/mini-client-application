// `.mcgen/manifest.json` (plan 02 section 2.6, ADR-0016): what mcgen last
// wrote. tool/loc reads `archetype` and `files.<path>.{hash,ownership}` from
// it (tool/loc/README.md); everything else is mcgen's own.

import 'dart:collection';
import 'dart:convert';

const manifestPath = '.mcgen/manifest.json';
const manifestSchema = 'mcgen-manifest/1';

class ManifestEntry {
  const ManifestEntry({
    required this.hash,
    required this.ownership,
    this.keep = const {},
  });

  /// sha256 of the content without keep-region bodies (see keep.dart).
  final String hash;

  /// `managed` or `owned`. For `owned`, [hash] is the first-write hash.
  final String ownership;

  /// Keep-region id -> sha256 of the region's *default* body (keep.dart
  /// `bodyHash`): what mcgen would emit there. A body that differs is
  /// hand-written.
  final Map<String, String> keep;

  Map<String, Object?> toJson() => {
    'hash': hash,
    if (keep.isNotEmpty)
      'keep': {for (final id in (keep.keys.toList()..sort())) id: keep[id]},
    'ownership': ownership,
  };

  @override
  bool operator ==(Object other) =>
      other is ManifestEntry &&
      other.hash == hash &&
      other.ownership == ownership &&
      _keepKey(other.keep) == _keepKey(keep);

  @override
  int get hashCode => Object.hash(hash, ownership, _keepKey(keep));

  static String _keepKey(Map<String, String> k) =>
      (k.keys.toList()..sort()).map((id) => '$id=${k[id]}').join(',');
}

class Manifest {
  Manifest({
    required this.generator,
    required this.module,
    required this.archetype,
    required this.ownership,
    required this.seed,
    required this.specHash,
    required Map<String, ManifestEntry> files,
  }) : files = SplayTreeMap.of(files);

  /// Parses [text]; throws [FormatException] on anything malformed.
  factory Manifest.decode(String text) {
    final j = jsonDecode(text);
    if (j is! Map<String, Object?>) {
      throw const FormatException('not a JSON object');
    }
    if (j['schema'] != manifestSchema) {
      throw FormatException(
        'schema is ${j['schema']}, expected $manifestSchema',
      );
    }
    String str(String k) {
      final v = j[k];
      if (v is! String) throw FormatException('"$k" must be a string');
      return v;
    }

    final files = j['files'];
    if (files is! Map<String, Object?>) {
      throw const FormatException('"files" must be an object');
    }
    return Manifest(
      generator: str('generator'),
      module: str('module'),
      archetype: str('archetype'),
      ownership: str('ownership'),
      seed: str('seed'),
      specHash: str('spec_hash'),
      files: {
        for (final e in files.entries)
          e.key: () {
            final v = e.value;
            if (v is! Map<String, Object?> ||
                v['hash'] is! String ||
                v['ownership'] is! String) {
              throw FormatException(
                'files["${e.key}"] needs string hash and ownership',
              );
            }
            final keep = v['keep'] ?? const <String, Object?>{};
            if (keep is! Map<String, Object?> ||
                keep.values.any((h) => h is! String)) {
              throw FormatException(
                'files["${e.key}"].keep must map region ids to hashes',
              );
            }
            if (v['ownership'] != 'managed' && v['ownership'] != 'owned') {
              throw FormatException(
                'files["${e.key}"].ownership must be managed or owned',
              );
            }
            return ManifestEntry(
              hash: v['hash']! as String,
              ownership: v['ownership']! as String,
              keep: keep.cast<String, String>(),
            );
          }(),
      },
    );
  }

  /// `mcgen <version>`.
  final String generator;
  final String module;
  final String archetype;

  /// The module's ownership mode.
  final String ownership;

  /// The module seed, as `0x` plus 16 hex digits.
  final String seed;
  final String specHash;

  /// Module-relative path -> entry, sorted by code unit.
  final SplayTreeMap<String, ManifestEntry> files;

  /// Sorted keys, two-space indent, LF, trailing newline: byte-stable.
  String encode() {
    final j = <String, Object?>{
      'archetype': archetype,
      'files': {for (final e in files.entries) e.key: e.value.toJson()},
      'generator': generator,
      'module': module,
      'ownership': ownership,
      'schema': manifestSchema,
      'seed': seed,
      'spec_hash': specHash,
    };
    return '${const JsonEncoder.withIndent('  ').convert(j)}\n';
  }
}
