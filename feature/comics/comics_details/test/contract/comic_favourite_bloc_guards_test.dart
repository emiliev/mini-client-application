// T-0050-AC2: the favourite bloc's own stale-state guard, on its own.
//
// The pin stops a write for another session, but the epoch it carries is the
// bloc's. If the bloc pinned the session's current epoch, a tap on a state
// that belongs to user A, handled after user B signed in (the bloc has not
// heard yet), would pass the pin and write under B's bearer. These tests run
// the real bloc and repository over the mocked backend with NO auth
// interceptor, so the bloc's check is the only protection. A reach into
// `src/` like the contract test (R7).
import 'dart:io';

import 'package:comics_details/src/domain/api/comics_details_api.dart';
import 'package:comics_details/src/domain/model/character_id.dart';
import 'package:comics_details/src/domain/model/comic_id.dart';
import 'package:comics_details/src/domain/model/creator_id.dart';
import 'package:comics_details/src/domain/repository/comics_details_repository.dart';
import 'package:comics_details/src/flow/comics_details_flow_state.dart';
import 'package:comics_details/src/navigator/comics_details_navigator.dart';
import 'package:comics_details/src/presentation/bloc/comic_favourite_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';

final class _Navigator implements ComicsDetailsNavigator {
  @override
  void openCharacter(CharacterId id) {}

  @override
  void openCreator(CreatorId id) {}

  @override
  Future<bool> requestSignIn() async => false;
}

AuthTokens _tokens(String user) => AuthTokens(
  accessToken: mintAccessToken(user, 1),
  refreshToken: mintRefreshToken(user, 1),
);

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  late Directory dir;
  late MockBackend backend;
  late Session session;
  late ComicFavouriteBloc bloc;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('mc_favourite_guards');
    backend = MockBackend(
      domains: const [ComicsMockDomain(), IdentityMockDomain()],
    );
    session = Session.empty(FileStore(dir));
    await session.signIn(userId: 'u-100', tokens: _tokens('u-100'));
    final dio = backend.createDio()
      ..options.headers['Authorization'] =
          'Bearer ${mintAccessToken('u-100', 1)}';
    bloc = ComicFavouriteBloc(
      ComicsDetailsRepository(ComicsDetailsApi(dio)),
      FeatureFlowController<ComicsDetailsFlowState>(
        const ComicsDetailsFlowState(comicId: ComicId(501500)),
      ),
      _Navigator(),
      session,
      EventBus(),
      Monitoring([]),
    );
    await _settle();
  });

  tearDown(() async {
    await bloc.close();
    await session.dispose();
    dir.deleteSync(recursive: true);
  });

  int writes(String method) => backend.recentTraffic
      .where(
        (t) => t.method == method && t.path.startsWith('/v1/me/favourites'),
      )
      .length;

  test('T-0050-AC2 a tap handled after another user signed in, before the '
      'bloc heard of it, writes nothing for them', () async {
    // User A saves the favourite and sees "Remove".
    bloc.add(const ComicFavouriteEvent.toggle());
    await _settle();
    expect(writes('PUT'), 1, reason: 'A saved it');

    // B signs in (in memory, at once); the tap comes in the same turn,
    // before the session's event reaches the bloc.
    bloc.add(const ComicFavouriteEvent.toggle());
    session.signIn(userId: 'u-101', tokens: _tokens('u-101')).ignore();
    await _settle();

    expect(
      writes('DELETE'),
      0,
      reason: 'a DELETE would remove a favourite B never saw',
    );
    expect(writes('PUT'), 1);
  });
}
