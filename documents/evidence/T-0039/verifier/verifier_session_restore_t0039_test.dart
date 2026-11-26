import 'package:app_core/app_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:mini_client/main.dart' as app;

/// T-0039 Verifier probe (not part of the branch): in the real app on a
/// simulator, through the real `main()`, a session saved in the app's storage
/// directory is restored at boot (the `SessionDIInitializer` read path, not
/// the empty-directory skip), and boot still reaches home.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0039 verifier: a populated store restores the session at '
      'boot in the real app', (tester) async {
    final dir = appStorageDirectory();
    final saved = await FileStore(dir).write('session', {
      'userId': 'u-100',
      'accessToken': 'mc-access-u-100-7',
      'refreshToken': 'mc-refresh-u-100-7',
    });
    expect(saved.getOrNull, isNotNull);
    expect(dir.listSync(), isNotEmpty, reason: 'the store is populated');

    startApp(app.main);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'the home page',
    );

    final reader = diContainer<SessionReader>();
    expect(reader.isSignedIn, isTrue, reason: 'restored at boot');
    expect(reader.userId, 'u-100');
    expect(reader.accessToken, 'mc-access-u-100-7');
    await shot(binding, tester, '01_home_with_restored_session');

    await FileStore(dir).delete('session');
  });
}
