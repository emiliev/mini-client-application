#!/usr/bin/python3 -I
"""Verifier's own mutations for T-0053. usage: vmut.py <id>  (applies) | list"""
import sys

AN = "utility/mc_analytics/lib/src/analytics.dart"
EV = "utility/mc_analytics/lib/src/event.dart"
CS = "utility/mc_analytics/lib/src/consent_store.dart"
RO = "utility/mc_analytics/lib/src/route_observer.dart"
M = {
    "V01": (AN, "(_seqs[entry.sessionId] ?? 0) + 1", "(_seqs[entry.sessionId] ?? 1) + 1", "seq starts at 2"),
    "V02": (AN, "const int analyticsBufferLimit = 100;", "const int analyticsBufferLimit = 101;", "buffer cap 101"),
    "V03": (AN, "        case AnalyticsConsent.denied:\n          _pending.clear();\n        case AnalyticsConsent.granted:", "        case AnalyticsConsent.denied:\n          break;\n        case AnalyticsConsent.granted:", "denied keeps buffer (denied then granted would flush)"),
    "V04": (AN, "    if (_consent == AnalyticsConsent.unknown) {\n      _pending.clear();\n    }\n    _startSession('reset');", "    _pending.clear();\n    _startSession('reset');", "reset drops queued granted entries too"),
    "V05": (CS, "(_) => AnalyticsConsent.unknown,", "(_) => fallback,", "damaged saved value falls back to the default"),
    "V06": (RO, "topRoute is! PageRoute<dynamic> || identical(topRoute, _last)", "topRoute is! PageRoute<dynamic>", "observer duplicates"),
    "V07": (RO, "topRoute is! PageRoute<dynamic> || identical(topRoute, _last)", "identical(topRoute, _last)", "dialogs tracked"),
    "V08": (EV, "static const int maxParams = 25;", "static const int maxParams = 26;", "25 params cap becomes 26"),
    "V09": (EV, "final length = value.runes.length;", "final length = value.length;", "string length counts UTF-16 units"),
    "V10": (AN, "if (_failedSinks.add(sink)) {", "if (true) {", "throwing sink reported every time"),
}
if sys.argv[1] == "list":
    print(" ".join(M))
    sys.exit(0)
if sys.argv[1] == "files":
    print(" ".join(sorted({v[0] for v in M.values()})))
    sys.exit(0)
f, old, new, what = M[sys.argv[1]]
s = open(f).read()
if s.count(old) != 1:
    print("NOT FOUND", sys.argv[1])
    sys.exit(3)
open(f, "w").write(s.replace(old, new))
print(what)
