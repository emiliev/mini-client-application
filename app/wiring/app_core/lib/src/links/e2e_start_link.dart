import 'dart:io';

/// The file name e2e scripts write into the app's data container `tmp/`
/// between install and launch (the R19 filter-file mechanism).
const String e2eStartLinkFile = 'mc_e2e_link';

/// Reads and deletes `<tmp>/mc_e2e_link`, a deep link to start at, or
/// returns null. `simctl openurl` can't be confirmed by a script (F-0020), so
/// e2e drives a deep link this way. The link then takes the same
/// PendingLinks → GoRouter path as a cold-start link. `main()` calls this
/// only outside release builds.
String? readE2eStartLink({Directory? tmp}) {
  final file = File('${(tmp ?? Directory.systemTemp).path}/$e2eStartLinkFile');
  if (!file.existsSync()) {
    return null;
  }
  final link = file.readAsStringSync().trim();
  file.deleteSync();
  return link.isEmpty ? null : link;
}
