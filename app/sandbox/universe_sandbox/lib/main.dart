import 'package:app_core/app_core.dart';
import 'package:flutter/widgets.dart';
import 'package:universe_sandbox/src/universe_sandbox_app.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final links = installSandboxLinks(binding);
  installErrorHooks();
  runApp(UniverseSandboxApp(links: links));
}
