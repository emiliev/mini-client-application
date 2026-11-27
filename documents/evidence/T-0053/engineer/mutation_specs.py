#!/usr/bin/python3 -I
"""The mutations of T-0053 (read by mutations.sh).

  mutation_specs.py list              ids, one per line
  mutation_specs.py files             every file a mutation touches
  mutation_specs.py targets <id>      the Bazel targets that must go red
  mutation_specs.py what <id>         the description
  mutation_specs.py file <id>         the file it edits (formatted afterwards: the
                                      Bazel build checks formatting, F-0051)
  mutation_specs.py apply <id>        applies it; exit 3 when the text is not
                                      found or the file did not change

Each entry replaces one exact piece of source (`old`) by `new`. A mutation
that cannot find its `old` fails loudly instead of passing as a no-op.
"""
import sys

A = "//utility/mc_analytics/..."
APP = ["//app/mini_client:analytics_screens_test", "//app/mini_client:bdd_test"]
STEPS = ["//utility/mc_test_steps:analytics_steps_test"]
CFG = ["//utility/mc_config/..."]

AN = "utility/mc_analytics/lib/src/analytics.dart"
EV = "utility/mc_analytics/lib/src/event.dart"
CO = "utility/mc_analytics/lib/src/consent.dart"
CS = "utility/mc_analytics/lib/src/consent_store.dart"
RO = "utility/mc_analytics/lib/src/route_observer.dart"
LO = "utility/mc_analytics/lib/src/lifecycle_observer.dart"
SK = "utility/mc_analytics/lib/src/sinks.dart"
DI = "utility/mc_analytics/lib/src/analytics_di_initializer.dart"
CFGSRC = "utility/mc_config/lib/src/app_config.dart"
E2EJSON = "tool/bazel/config/e2e.json"
ROOT = "app/wiring/app_core/lib/src/di/root_initializers.dart"
OBS = "app/wiring/app_core/lib/src/router/router_observers.dart"
ROUTER = "app/mini_client/lib/src/router/app_router.dart"
ROUTES = "app/mini_client/lib/src/router/app_routes.dart"
CHARS = "app/wiring/universe_wiring/lib/src/routes/characters_routes.dart"
TC = "utility/mc_test_utils/lib/src/test_container.dart"
S1 = "utility/mc_test_steps/lib/src/analytics/the_analytics_event_was_tracked.dart"
S2 = "utility/mc_test_steps/lib/src/analytics/the_analytics_event_was_tracked_with.dart"
S3 = "utility/mc_test_steps/lib/src/analytics/no_analytics_event_was_tracked.dart"
S4 = "utility/mc_test_steps/lib/src/analytics/the_screen_was_tracked.dart"

# (id, description, file, [(old, new), ...], targets)
M = [
    # ---- AC1: the consent gate -------------------------------------------
    ("G01", "the gate is removed from the drain loop (delivers whatever the consent)", AN,
     [("while (_consent == AnalyticsConsent.granted && _pending.isNotEmpty) {",
       "while (_pending.isNotEmpty) {")], [A]),
    ("G02", "unknown delivers too", AN,
     [("while (_consent == AnalyticsConsent.granted && _pending.isNotEmpty) {",
       "while (_consent != AnalyticsConsent.denied && _pending.isNotEmpty) {"),
      ("        _pending.add(entry);\n        _trimToLimit();\n",
       "        _pending.add(entry);\n        _trimToLimit();\n        _scheduleDrain();\n")], [A]),
    ("G03", "denied still buffers what is tracked", AN,
     [("      case AnalyticsConsent.denied:\n        return;\n",
       "      case AnalyticsConsent.denied:\n        _pending.add(entry);\n        return;\n")], [A]),
    ("G04", "switching to denied keeps the buffer", AN,
     [("        case AnalyticsConsent.denied:\n          _pending.clear();\n",
       "        case AnalyticsConsent.denied:\n          break;\n")], [A]),
    ("G05", "granting does not flush the buffer", AN,
     [("          if (_pending.isNotEmpty) {\n            _scheduleDrain();\n          }\n", "")], [A]),
    ("G06", "the flush runs newest first (order)", AN,
     [("final entry = _pending.removeFirst();", "final entry = _pending.removeLast();")], [A]),
    ("G07", "delivery is inline (a same-turn denied cannot stop it)", AN,
     [("      case AnalyticsConsent.granted:\n        _pending.add(entry);\n        _scheduleDrain();\n",
       "      case AnalyticsConsent.granted:\n        _pending.add(entry);\n        _drain();\n")], [A]),
    ("G08", "consent is read once per flush, not per entry", AN,
     [("    while (_consent == AnalyticsConsent.granted && _pending.isNotEmpty) {",
       "    final go = _consent == AnalyticsConsent.granted;\n    while (go && _pending.isNotEmpty) {")], [A]),
    ("G09", "buffer cap 101 (boundary)", AN,
     [("const int analyticsBufferLimit = 100;", "const int analyticsBufferLimit = 101;")], [A]),
    ("G10", "buffer cap 99 (boundary)", AN,
     [("const int analyticsBufferLimit = 100;", "const int analyticsBufferLimit = 99;")], [A]),
    ("G11", "the newest is dropped instead of the oldest", AN,
     [("      _pending.removeFirst();\n      droppedNow++;", "      _pending.removeLast();\n      droppedNow++;")], [A]),
    ("G12", "the first overflow is not reported", AN,
     [("    if (first) {\n      _reportOverflow();\n    }\n", "")], [A]),
    ("G13", "the total dropped is not reported when consent is chosen", AN,
     [("    if (_droppedInPeriod != _reportedInPeriod) {\n      _reportOverflow();\n    }\n", "")], [A]),
    ("G14", "a new unknown period keeps the old counters", AN,
     [("    _droppedInPeriod = 0;\n    _reportedInPeriod = 0;\n", "")], [A]),
    ("G15", "going back to unknown does not trim to 100", AN,
     [("        case AnalyticsConsent.unknown:\n          _trimToLimit();\n",
       "        case AnalyticsConsent.unknown:\n          break;\n")], [A]),
    ("G16", "consentChanges repeats an unchanged value", AN,
     [("    if (previous != next) {", "    if (true) {")], [A]),
    ("G17", "a failed save is not reported", AN,
     [("    } on Object catch (error, stack) {\n      unawaited(_monitoring.recordError(error, stack));\n    }\n  }\n\n  void _reject",
       "    } on Object {\n      // swallowed\n    }\n  }\n\n  void _reject")], [A]),
    ("G18", "reset keeps what was waiting", AN,
     [("  void reset() {\n    _pending.clear();\n", "  void reset() {\n")], [A]),
    ("G19", "an unrecognised consent value grants", CO,
     [("    return unknown;\n  }\n}", "    return granted;\n  }\n}")], [A]),
    ("G20", "a damaged saved value falls back to the default", CS,
     [("      (_) => AnalyticsConsent.unknown,", "      (_) => fallback,")], [A]),
    ("G21", "the saved choice is ignored at restore", CS,
     [("    if (!saved) {", "    if (true) {")], [A]),
    ("G22", "the wrong value is saved", CS,
     [("_store.write(key, consent.name)", "_store.write(key, 'granted')")], [A]),
    ("G23", "a failed write is swallowed", CS,
     [("written.fold((_) {}, (failure) => throw failure);", "written.fold((_) {}, (failure) {});")], [A]),
    ("G24", "the saved choice is not read at boot (DI)", DI,
     [("consent: await store.restore(fallback),", "consent: fallback,")], [A]),
    ("G25", "the choice is not persisted (DI)", DI,
     [("      persist: store.save,\n", "")], [A]),
    ("G26", "the config default is ignored (DI)", DI,
     [("getIt<AppConfig>().analytics.defaultConsent,", "'unknown',")], [A]),
    ("G27", "the config default parses to granted when missing", CFGSRC,
     [("(json?['defaultConsent'] as String?) ?? 'unknown'", "(json?['defaultConsent'] as String?) ?? 'granted'")], CFG),
    ("G28", "e2e config no longer grants consent", E2EJSON,
     [('"defaultConsent": "granted"', '"defaultConsent": "unknown"')],
     ["--//tool/bazel/config:env=e2e", "//utility/mc_config:bundled_config_test"]),
    # ---- AC2: validation -------------------------------------------------
    ("V01", "name limit 41", EV,
     [("static const int maxNameLength = 40;", "static const int maxNameLength = 41;")], [A]),
    ("V02", "name limit 39", EV,
     [("static const int maxNameLength = 40;", "static const int maxNameLength = 39;")], [A]),
    ("V03", "25 params limit becomes 26", EV,
     [("static const int maxParams = 25;", "static const int maxParams = 26;")], [A]),
    ("V04", "25 params limit becomes 24", EV,
     [("static const int maxParams = 25;", "static const int maxParams = 24;")], [A]),
    ("V05", "string limit 101", EV,
     [("static const int maxStringLength = 100;", "static const int maxStringLength = 101;")], [A]),
    ("V06", "string length counted in UTF-16 units", EV,
     [("final length = value.runes.length;", "final length = value.length;")], [A]),
    ("V07", "the ga_ prefix is not reserved", EV,
     [("    'ga_',\n", "")], [A]),
    ("V08", "the mc_ prefix is not reserved", EV,
     [("    kitPrefix,\n", "")], [A]),
    ("V09", "snake_case allows trailing and double underscores", EV,
     [("r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$'", "r'^[a-z][a-z0-9_]*$'")], [A]),
    ("V10", "NaN and infinity are accepted", EV,
     [("        if (!value.isFinite)", "        if (false)")], [A]),
    ("V11", "the kit's param keys can be passed", EV,
     [("if (!allowReserved && reservedParamKeys.contains(key)) {", "if (false) {")], [A]),
    ("V12", "isValidName ignores the length", EV,
     [("name.length <= maxNameLength && _snakeCase", "_snakeCase")], [A]),
    ("V13", "any value type is accepted", EV,
     [("    if (value is int || value is bool) {", "    if (true) {")], [A]),
    ("V14", "debug mode does not throw", AN,
     [("    if (_debugMode) {\n      throw", "    if (false) {\n      throw")], [A]),
    ("V15", "release mode throws too", AN,
     [("    if (_debugMode) {\n      throw", "    if (true) {\n      throw")], [A]),
    ("V16", "release mode drops without reporting", AN,
     [("    unawaited(_monitoring.recordError(error, null));\n", "")], [A]),
    ("V17", "the screen name is not validated", AN,
     [("      ...AnalyticsRules.validateName(name, allowReserved: true),\n", "")], [A]),
    ("V18", "the user property is not validated", AN,
     [("      ...AnalyticsRules.validateName(key),\n      ...AnalyticsRules.validateValue('value', value),\n",
       "      ...<AnalyticsViolation>[],\n")], [A]),
    ("V19", "the caller's params map is kept, not copied", AN,
     [("Map<String, Object>.unmodifiable(params)", "params")], [A]),
    # ---- AC3: sessions and sinks ----------------------------------------
    ("S01", "rotation needs more than 30:00", AN,
     [(">= analyticsSessionTimeout", "> analyticsSessionTimeout")], [A]),
    ("S02", "the timeout is 29 minutes", AN,
     [("const Duration analyticsSessionTimeout = Duration(minutes: 30);", "const Duration analyticsSessionTimeout = Duration(minutes: 29);")], [A]),
    ("S03", "the timeout is 31 minutes", AN,
     [("const Duration analyticsSessionTimeout = Duration(minutes: 30);", "const Duration analyticsSessionTimeout = Duration(minutes: 31);")], [A]),
    ("S04", "a second backgrounding moves the start time", AN,
     [("_backgroundedAt ??= _clock();", "_backgroundedAt = _clock();")], [A]),
    ("S05", "coming back does not clear the background time", AN,
     [("    final since = _backgroundedAt;\n    _backgroundedAt = null;\n", "    final since = _backgroundedAt;\n")], [A]),
    ("S06", "a rotation starts no session event", AN,
     [("      _startSession('timeout');", "      _sessionId = _newSessionId();")], [A]),
    ("S07", "reset does not start a new session", AN,
     [("    _startSession('reset');", "    _enqueueEvent(sessionStartEventName, {'reason': 'reset'});")], [A]),
    ("S08", "seq is counted across sessions", AN,
     [("      final seq = (_seqs[entry.sessionId] ?? 0) + 1;\n      _seqs[entry.sessionId] = seq;\n",
       "      final seq = (_seqs[''] ?? 0) + 1;\n      _seqs[''] = seq;\n")], [A]),
    ("S09", "seq starts at 0", AN,
     [("(_seqs[entry.sessionId] ?? 0) + 1;", "(_seqs[entry.sessionId] ?? -1) + 1;")], [A]),
    ("S10", "seq is counted against the current session, not the entry's", AN,
     [("      final seq = (_seqs[entry.sessionId] ?? 0) + 1;\n      _seqs[entry.sessionId] = seq;\n",
       "      final seq = (_seqs[_sessionId] ?? 0) + 1;\n      _seqs[_sessionId] = seq;\n")], [A]),
    ("S11", "the session id does not come from the injected random", AN,
     [("_random.nextInt(1 << 32)", "Random().nextInt(1 << 32)")], [A]),
    ("S12", "the session start reason is wrong", AN,
     [("_startSession('cold_start');", "_startSession('cold');")], [A]),
    ("S13", "a throwing sink stops the others", AN,
     [("      try {\n        sink.record(record);\n      } on Object catch (error, stack) {\n        if (_failedSinks.add(sink)) {\n          unawaited(_monitoring.recordError(error, stack));\n        }\n      }\n",
       "      sink.record(record);\n")], [A]),
    ("S14", "a throwing sink is reported every time", AN,
     [("if (_failedSinks.add(sink)) {", "if (_failedSinks.add(sink) || true) {")], [A]),
    ("S15", "a throwing sink is not reported", AN,
     [("        if (_failedSinks.add(sink)) {\n          unawaited(_monitoring.recordError(error, stack));\n        }\n", "")], [A]),
    ("S16", "inactive counts as background", LO,
     [("      case AppLifecycleState.inactive:\n        break;", "      case AppLifecycleState.inactive:\n        _analytics.appBackgrounded();")], [A]),
    ("S17", "hidden does not count as background", LO,
     [("      case AppLifecycleState.hidden:\n      case AppLifecycleState.paused:", "      case AppLifecycleState.paused:"),
      ("      case AppLifecycleState.inactive:\n        break;", "      case AppLifecycleState.hidden:\n      case AppLifecycleState.inactive:\n        break;")], [A]),
    ("S18", "resumed does not foreground", LO,
     [("        _analytics.appForegrounded();", "        break;")], [A]),
    ("S19", "the monitoring sink drops seq", SK,
     [("          'seq': record.seq,\n", "")], [A]),
    ("S20", "the monitoring sink names a user property differently", SK,
     [("        'user_property',", "        'user_prop',")], [A]),
    ("S21", "the in-memory sink reads the wrong screen key", SK,
     [("e.params['screen_name']! as String", "e.params['screen']! as String")], [A]),
    ("S22", "the observer is not removed on dispose", DI,
     [("        widgets?.removeObserver(observer);\n", "")], [A]),
    ("S23", "observeLifecycle false is ignored", DI,
     [("    final widgets = observeLifecycle\n        ? (binding ?? WidgetsBinding.instance)\n        : null;",
       "    final widgets = binding ?? WidgetsBinding.instance;")], [A]),
    ("S24", "the default sink is not the monitoring sink", DI,
     [("sinks ?? [MonitoringAnalyticsSink(monitoring)]", "sinks ?? <AnalyticsSink>[]")], [A]),
    # ---- AC4: screens ---------------------------------------------------
    ("R01", "popup routes are tracked as the last page (a dialog repeats the page)", RO,
     [("if (topRoute is! PageRoute<dynamic> || identical(topRoute, _last)) {", "if (identical(topRoute, _last)) {")], [A]),
    ("R02", "the same route becoming top again is tracked again", RO,
     [("if (topRoute is! PageRoute<dynamic> || identical(topRoute, _last)) {", "if (topRoute is! PageRoute<dynamic>) {")], [A]),
    ("R03", "an unnamed page does not count as a change", RO,
     [("    _last = topRoute;\n    final name = topRoute.settings.name;\n    if (name == null || !AnalyticsRules.isValidName(name)) {\n      return;\n    }\n",
       "    final name = topRoute.settings.name;\n    if (name == null || !AnalyticsRules.isValidName(name)) {\n      return;\n    }\n    _last = topRoute;\n")], [A]),
    ("R04", "names that are not screen names are passed on", RO,
     [("    if (name == null || !AnalyticsRules.isValidName(name)) {", "    if (name == null) {")], [A]),
    ("R05", "the observer reports the route's arguments instead of its name", RO,
     [("    _resolve().screen(name);", "    _resolve().screen('home');")], [A]),
    # ---- AC4/AC5: the app and the steps --------------------------------
    ("W01", "the analytics initializer leaves the root list", ROOT,
     [("    AnalyticsDIInitializer(sinks: analyticsSinks),\n", "")], APP),
    ("W02", "the router has no analytics observer", ROUTER,
     [("  observers: appRouterObservers(),\n", "")], APP),
    ("W03", "appRouterObservers returns nothing", OBS,
     [("  AnalyticsRouteObserver.lazy(() => diContainer<Analytics>()),\n", "")], APP),
    ("W04", "home has no page name", ROUTES,
     [("  name: 'home',\n", "")], APP),
    ("W05", "characters has no page name", CHARS,
     [("  name: 'characters_list',\n", "")], APP),
    ("W06", "the test container has no analytics", TC,
     [("    AnalyticsDIInitializer(\n      sinks: [session.analytics],\n      observeLifecycle: false,\n    ),\n", "")], STEPS + APP),
    ("W07", "the test container's sink is not the session's", TC,
     [("sinks: [session.analytics],", "sinks: <AnalyticsSink>[],")], STEPS + APP),
    ("W08", "the screen step accepts any screen", S4,
     [("    contains(name),", "    isNotNull,")], STEPS),
    ("W09", "the event step ignores the name", S1,
     [("events.where((e) => e.name == name),", "events,")], STEPS),
    ("W10", "the event-with-params step ignores the params", S2,
     [("events.any((e) => mapEquals<String, Object?>(e.params, expected)),", "events.any((e) => true),")], STEPS),
    ("W11", "the no-event step counts nothing", S3,
     [("      if (e.name != sessionStartEventName && e.name != screenViewEventName)\n        e.name,\n",
       "      if (false) e.name,\n")], STEPS),
    ("W12", "the no-event step counts the kit's session start", S3,
     [("      if (e.name != sessionStartEventName && e.name != screenViewEventName)", "      if (e.name != screenViewEventName)")], STEPS),
]

if __name__ == "__main__":
    cmd = sys.argv[1]
    by_id = {m[0]: m for m in M}
    if cmd == "list":
        print("\n".join(m[0] for m in M))
    elif cmd == "files":
        print("\n".join(sorted({m[2] for m in M})))
    elif cmd == "targets":
        print(" ".join(by_id[sys.argv[2]][4]))
    elif cmd == "file":
        print(by_id[sys.argv[2]][2])
    elif cmd == "what":
        print(by_id[sys.argv[2]][1])
    elif cmd == "apply":
        _, _, path, edits, _ = by_id[sys.argv[2]]
        text = open(path).read()
        out = text
        for old, new in edits:
            if old not in out:
                print("TEXT NOT FOUND: %r" % old[:70])
                sys.exit(3)
            out = out.replace(old, new, 1)
        if out == text:
            print("MUTATION DID NOT CHANGE THE FILE")
            sys.exit(3)
        open(path, "w").write(out)
    else:
        sys.exit(2)
