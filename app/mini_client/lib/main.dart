import 'package:app_core/app_core.dart';
import 'package:flutter/widgets.dart';
import 'package:mini_client/src/mini_client_app.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Before runApp, so it is the first observer and holds the cold-start link
  // and any link that arrives during boot (R29).
  final links = PendingLinks.install(binding);
  installErrorHooks();
  runApp(MiniClientApp(links: links));
}
