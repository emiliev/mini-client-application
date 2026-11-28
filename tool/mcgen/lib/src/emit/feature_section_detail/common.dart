// Helpers the section-detail emitters share.

import 'package:mcgen/src/core/ir/symbols.dart';

export 'package:mcgen/src/emit/feature_list_detail/common.dart'
    show
        commentLines,
        dartAsync,
        docLines,
        documented,
        flutterTest,
        keepRegion,
        literal,
        material,
        needsRequired,
        participle,
        ty,
        tyName,
        widgets,
        words;
export 'package:mcgen/src/emit/feature_list_detail/tests.dart' show tpl;

/// First-party and third-party names the SC templates use that the shared
/// kit table does not list. Registered when no one has registered them yet,
/// so growing the shared table never conflicts with this one.
const _scSymbols = <String, List<String>>{
  'package:dio/dio.dart': ['DioException'],
  'package:retrofit/retrofit.dart': ['Extras', 'Path'],
  'package:mc_api_auth/mc_api_auth.dart': ['AuthApi', 'authPinned'],
  'package:mc_analytics/mc_analytics.dart': ['AnalyticsFlowObserver'],
  'package:mc_monitoring/mc_monitoring.dart': ['AnalyticsTracker'],
  'package:mc_event_bus/mc_event_bus.dart': ['DataChanged', 'EventBus'],
  'package:mc_feature_flow/mc_feature_flow.dart': ['FlowScope'],
  'package:mc_session/mc_session.dart': ['AuthStatus', 'SessionReader'],
  'package:mc_api_errors/mc_api_errors.dart': ['ApiNotFound'],
  'package:mc_ds_theme/mc_ds_theme.dart': ['McThemeContext'],
  'package:mc_di/mc_di.dart': ['diContainer'],
};

void registerScSymbols(SymbolTable table) {
  _scSymbols.forEach((uri, names) {
    for (final n in names) {
      if (table.lookup(n).isEmpty) table.external(n, uri);
    }
  });
}

/// [text] filled greedily to [width] columns, one paragraph per blank-line
/// group, as a hand-wrapped doc comment at [indent] columns reads. A
/// paragraph with a list line (`- `, `1. `) or an indented line is kept as
/// written.
String reflow(String text, {int indent = 0, int width = 78}) {
  final room = width - indent - 4;
  final out = <String>[];
  for (final para in text.trim().split('\n\n')) {
    final lines = para.split('\n');
    if (lines.any((l) => l.startsWith(RegExp(r'(- |\d+\. |\s)')))) {
      out.addAll(lines);
    } else {
      var line = '';
      for (final w in para.split(RegExp(r'\s+'))) {
        if (line.isEmpty) {
          line = w;
        } else if (line.length + 1 + w.length <= room) {
          line = '$line $w';
        } else {
          out.add(line);
          line = w;
        }
      }
      out.add(line);
    }
    out.add('');
  }
  out.removeLast();
  return out.join('\n');
}
