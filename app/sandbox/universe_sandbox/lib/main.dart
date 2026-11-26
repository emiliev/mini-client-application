import 'package:app_core/app_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:universe_sandbox/src/universe_sandbox_app.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final links = installSandboxLinks(binding);
  if (!kReleaseMode) {
    // e2e drives deep links through a file, not `simctl openurl` (F-0020),
    // as in mini_client.
    final link = readE2eStartLink();
    if (link != null) {
      links.offer(link);
    }
  }
  installErrorHooks();
  runApp(UniverseSandboxApp(links: links));
}
