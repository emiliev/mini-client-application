import 'package:app_core/app_core.dart';
import 'package:injectable/injectable.dart';
import 'package:library_reading_list_editor/library_reading_list_editor.dart';
import 'package:mc_session/mc_session.dart';

/// library_reading_list_editor's way out of the feature. It holds the
/// [RouterRef], not a router, and asks for the live router at each call
/// (T-0033).
///
/// - Signing in is the app's business: `requestAppSignIn` (app_core) opens the
///   sign-in screen (T-0066).
/// - The editor's result is not a navigator call: the route hands the flow's
///   result back to whoever pushed it (`FlowResultRoute`, `AppFlows`).
@LazySingleton(as: ReadingListEditorNavigator)
class ReadingListEditorNavigatorImpl implements ReadingListEditorNavigator {
  ReadingListEditorNavigatorImpl(this._routerRef, this._session);

  final RouterRef _routerRef;
  final SessionReader _session;

  @override
  Future<bool> requestSignIn() => requestAppSignIn(
    routerRef: _routerRef,
    session: _session,
    purpose: SignInPurpose.readingLists,
  );
}
