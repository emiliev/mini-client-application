import 'package:app_core/app_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mini_client/src/mini_client_app.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Before runApp, so it is the first observer and holds the cold-start link
  // and any link that arrives during boot (R29).
  final links = PendingLinks.install(binding);
  if (!kReleaseMode) {
    // e2e drives deep links through a file, not `simctl openurl` (F-0020).
    final link = readE2eStartLink();
    if (link != null) {
      links.offer(link);
    }
  }
  installErrorHooks();
  runApp(MiniClientApp(links: links));
}
