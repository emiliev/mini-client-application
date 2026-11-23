import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

/// Result of applying the D8 rule to one file.
class FileScan {
  FileScan(this.lines, this.imports, this.mixins);

  /// 1-based line numbers that count: covered by at least one non-comment
  /// token and containing a non-whitespace character.
  final Set<int> lines;
  final int imports;
  final int mixins;
}

/// Counts lines of [content] per plan 02 section 4.1.
///
/// The file is tokenised by the analyzer; `precedingComments` are never
/// visited, so comments (line, block, nested block, doc) contribute nothing.
/// Every line spanned by a real token is marked, so multi-line strings count.
FileScan scanDart(String content) {
  final result = parseString(content: content, throwIfDiagnostics: false);
  final lineInfo = result.lineInfo;
  final text = content.split('\n');
  final lines = <int>{};
  var mixins = 0;
  Token token = result.unit.beginToken;
  while (token.type != TokenType.EOF) {
    if (token.length > 0) {
      final first = lineInfo.getLocation(token.offset).lineNumber;
      final last = lineInfo.getLocation(token.end - 1).lineNumber;
      for (var l = first; l <= last; l++) {
        if (l - 1 < text.length && text[l - 1].trim().isNotEmpty) lines.add(l);
      }
      if (token.type == Keyword.MIXIN) mixins++;
    }
    token = token.next!;
  }
  final imports = result.unit.directives.whereType<ImportDirective>().length;
  return FileScan(lines, imports, mixins);
}

/// 1-based lines strictly between `// mcgen:keep <id>` and `// mcgen:end <id>`.
Set<int> keepRegionLines(String content) {
  final out = <int>{};
  final text = content.split('\n');
  String? open;
  for (var i = 0; i < text.length; i++) {
    final t = text[i].trim();
    final keep = RegExp(r'^// mcgen:keep (\S+)').firstMatch(t);
    final end = RegExp(r'^// mcgen:end (\S+)').firstMatch(t);
    if (open == null && keep != null) {
      open = keep.group(1);
    } else if (open != null && end != null && end.group(1) == open) {
      open = null;
    } else if (open != null) {
      out.add(i + 1);
    }
  }
  return out;
}

/// Content with keep-region bodies removed, used for the manifest hash.
String stripKeepRegions(String content) {
  final keep = keepRegionLines(content);
  final text = content.split('\n');
  final buf = <String>[];
  for (var i = 0; i < text.length; i++) {
    if (!keep.contains(i + 1)) buf.add(text[i]);
  }
  return buf.join('\n');
}
