import 'package:app_core/app_core.dart';
import 'package:flutter/widgets.dart';
import 'package:universe_sandbox/src/universe_sandbox_app.dart';
import 'package:universe_sandbox/src/universe_sandbox_router.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final links = PendingLinks.install(binding, scheme: sandboxLinkScheme);
  installErrorHooks();
  runApp(UniverseSandboxApp(links: links));
}
