import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the flag {'store.home_featured'} is {false}
///
/// The remote value of the feature flag with that key, in the test
/// container's stub snapshot (`McTestFlags`, P-107). The feature reads it
/// with the flag's own codec, so a value of the wrong type is the flag's
/// default, as in the app. A literal (`{false}`, `{3}`) is the value; a
/// string is read as JSON when it parses (`{'true'}`, `{'3'}`) and is the
/// text otherwise (`{'list'}` for an enum flag). Set it before the step that
/// opens the flow: a feature reads its flags when its page opens.
Future<void> theFlagIs(WidgetTester tester, String key, Object value) async {
  McTestSession.current.flags.set(key, _raw(value));
}

Object _raw(Object value) {
  if (value is! String) {
    return value;
  }
  try {
    return jsonDecode(value) as Object;
  } on FormatException {
    return value;
  }
}
