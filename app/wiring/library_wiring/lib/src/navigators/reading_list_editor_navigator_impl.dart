import 'package:app_core/app_core.dart';
import 'package:injectable/injectable.dart';
import 'package:library_reading_list_editor/library_reading_list_editor.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_session/mc_session.dart';

/// library_reading_list_editor's way out of the feature. It holds the
/// [RouterRef], not a router, and asks for the live router at each call
/// (T-0033).
///
/// - Signing in is the app's business: until the sign-in feature exists, the
///   temporary fixture sheet `app_core` shares between the wirings signs a
///   fixture user in (P-044).
/// - The editor's result is not a navigator call: the route hands the flow's
///   result back to whoever pushed it (`FlowResultRoute`, `AppFlows`).
@LazySingleton(as: ReadingListEditorNavigator)
class ReadingListEditorNavigatorImpl implements ReadingListEditorNavigator {
  ReadingListEditorNavigatorImpl(this._routerRef, this._session, this._auth);

  final RouterRef _routerRef;
  final SessionReader _session;
  final AuthApi _auth;

  @override
  Future<bool> requestSignIn() => requestFixtureSignIn(
    routerRef: _routerRef,
    session: _session,
    auth: _auth,
    reason: 'to save your reading lists',
  );
}
