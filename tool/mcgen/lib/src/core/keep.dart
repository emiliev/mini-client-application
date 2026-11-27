// Keep regions (plan 02 section 2.6): `// mcgen:keep <id>` ... `// mcgen:end <id>`.
//
// The hash rule is tool/loc's (tool/loc/lib/count.dart `stripKeepRegions`),
// line for line, so a file mcgen calls scaffold is the file loc counts as
// scaffold: the sha256 of the content without the lines strictly between a
// keep marker and its end marker, joined with LF.

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The line-comment prefix keep markers use in a file, or null when the file
/// kind has no keep regions.
String? keepPrefixFor(String path) {
  if (path.endsWith('.dart')) return '//';
  if (path.endsWith('.yaml') || path.endsWith('.yml')) return '#';
  return null;
}

RegExp _keepRe(String prefix) =>
    RegExp('^${RegExp.escape(prefix)} mcgen:keep (\\S+)');

RegExp _endRe(String prefix) =>
    RegExp('^${RegExp.escape(prefix)} mcgen:end (\\S+)');

/// One region: [start] and [end] are the 0-based marker line indexes.
class KeepRegion {
  const KeepRegion(this.id, this.start, this.end, this.body);

  final String id;
  final int start;
  final int end;

  /// The lines strictly between the markers, verbatim.
  final List<String> body;
}

/// Something wrong with a file's markers.
class KeepDamage {
  const KeepDamage(this.line, this.message);

  /// 1-based.
  final int line;
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// The regions of a file, and any damage to its markers.
class KeepScan {
  KeepScan._(this.regions, this.damage);

  /// Scans [content] with [prefix] (`//` or `#`).
  factory KeepScan.of(String content, String prefix) {
    final keepRe = _keepRe(prefix);
    final endRe = _endRe(prefix);
    final lines = content.split('\n');
    final regions = <KeepRegion>[];
    final damage = <KeepDamage>[];
    final seen = <String>{};
    String? openId;
    var openAt = -1;
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].trim();
      final k = keepRe.firstMatch(t);
      final e = endRe.firstMatch(t);
      if (k != null) {
        if (openId != null) {
          damage.add(
            KeepDamage(
              i + 1,
              'keep "${k[1]}" opened inside keep "$openId" (line ${openAt + 1})',
            ),
          );
          continue;
        }
        openId = k[1];
        openAt = i;
        if (!seen.add(openId!)) {
          damage.add(KeepDamage(i + 1, 'keep "$openId" appears twice'));
        }
      } else if (e != null) {
        if (openId == null) {
          damage.add(KeepDamage(i + 1, 'end "${e[1]}" without a keep'));
        } else if (e[1] != openId) {
          damage.add(
            KeepDamage(
              i + 1,
              'end "${e[1]}" closes keep "$openId" (line ${openAt + 1})',
            ),
          );
        } else {
          regions.add(
            KeepRegion(openId, openAt, i, lines.sublist(openAt + 1, i)),
          );
          openId = null;
        }
      }
    }
    if (openId != null) {
      damage.add(KeepDamage(openAt + 1, 'keep "$openId" is never closed'));
    }
    return KeepScan._(regions, damage);
  }

  final List<KeepRegion> regions;
  final List<KeepDamage> damage;

  bool get ok => damage.isEmpty;

  List<String> get ids => [for (final r in regions) r.id];

  KeepRegion? operator [](String id) {
    for (final r in regions) {
      if (r.id == id) return r;
    }
    return null;
  }
}

/// tool/loc's `stripKeepRegions`, generalised to a comment [prefix].
String stripKeepRegions(String content, String prefix) {
  final keepRe = _keepRe(prefix);
  final endRe = _endRe(prefix);
  final lines = content.split('\n');
  final out = <String>[];
  String? open;
  for (final line in lines) {
    final t = line.trim();
    final keep = keepRe.firstMatch(t);
    final end = endRe.firstMatch(t);
    if (open == null && keep != null) {
      open = keep.group(1);
      out.add(line);
    } else if (open != null && end != null && end.group(1) == open) {
      open = null;
      out.add(line);
    } else if (open == null) {
      out.add(line);
    }
  }
  return out.join('\n');
}

/// The manifest hash of a file: sha256 of its content without keep-region
/// bodies (files with no keep syntax: of the whole content).
String contentHash(String path, String content) {
  final prefix = keepPrefixFor(path);
  final text = prefix == null ? content : stripKeepRegions(content, prefix);
  return sha256.convert(utf8.encode(text)).toString();
}

/// The result of carrying hand-written region bodies into fresh output.
class Splice {
  const Splice(this.content, this.kept, this.orphans);

  final String content;

  /// Region ids whose existing body was carried over.
  final List<String> kept;

  /// Region ids in the old file that the new output no longer has, and whose
  /// body was not empty: carrying on would lose hand-written code.
  final List<String> orphans;
}

/// Replaces each region body in [fresh] by the same region's body in
/// [existing]. Both must scan clean (see [KeepScan.ok]).
Splice spliceKeepRegions(String fresh, String existing, String prefix) {
  final newScan = KeepScan.of(fresh, prefix);
  final oldScan = KeepScan.of(existing, prefix);
  if (!newScan.ok) {
    throw StateError(
      'generated output has damaged keep markers: ${newScan.damage.join('; ')}',
    );
  }
  if (!oldScan.ok) {
    throw StateError(
      'existing file has damaged keep markers: ${oldScan.damage.join('; ')}',
    );
  }
  final lines = fresh.split('\n');
  final out = <String>[];
  final kept = <String>[];
  var i = 0;
  for (final r in newScan.regions) {
    out.addAll(lines.sublist(i, r.start + 1));
    final old = oldScan[r.id];
    if (old != null) {
      out.addAll(old.body);
      kept.add(r.id);
    } else {
      out.addAll(r.body);
    }
    i = r.end;
  }
  out.addAll(lines.sublist(i));
  final newIds = newScan.ids.toSet();
  final orphans = [
    for (final r in oldScan.regions)
      if (!newIds.contains(r.id) && r.body.any((l) => l.trim().isNotEmpty))
        r.id,
  ];
  return Splice(out.join('\n'), kept, orphans);
}
