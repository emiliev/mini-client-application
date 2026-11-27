// T-0067-AC3 (from T-0050-AC2): the favourite bloc's own stale-state guard,
// on its own.
//
// The pin stops a write for another session, but the epoch it carries is the
// bloc's. If the bloc pinned the session's current epoch, a tap on a state
// that belongs to user A, handled after user B signed in (the bloc has not
// heard yet), would pass the pin and write under B's bearer. These tests run
// the real bloc and repository over the mocked backend with NO auth
// interceptor, so the bloc's check is the only protection. A reach into
// `src/` like the contract test (R7).
import 'dart:io';

import 'package:characters_details/src/domain/api/characters_details_api.dart';
import 'package:characters_details/src/domain/model/character_id.dart';
import 'package:characters_details/src/domain/model/comic_id.dart';
import 'package:characters_details/src/domain/repository/characters_details_repository.dart';
import 'package:characters_details/src/flow/characters_details_flow_state.dart';
import 'package:characters_details/src/navigator/characters_details_navigator.dart';
import 'package:characters_details/src/presentation/bloc/character_details_bloc.dart';
import 'package:characters_details/src/presentation/bloc/character_favourite_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';

final class _Navigator implements CharacterDetailsNavigator {
  final List<int> opened = [];

  @override
  void openComic(ComicId id) => opened.add(id.value);

  @override
  Future<bool> requestSignIn() async => false;
}

final class _Tracker implements AnalyticsTracker {
  /// Each event as `name key=value ...`, in order.
  final List<String> tracked = [];

  @override
  void trackEvent(String name, [Map<String, Object> params = const {}]) =>
      tracked.add(
        [name, for (final e in params.entries) '${e.key}=${e.value}'].join(' '),
      );

  @override
  void trackScreen(String name) {}
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
  late _Tracker tracker;
  late CharacterFavouriteBloc bloc;
  // Saves the tests did not await: tearDown awaits them before it deletes
  // the storage folder (T-0050 D1).
  final saves = <Future<Object?>>[];

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('mc_character_guards');
    backend = MockBackend(
      domains: const [
        CharactersMockDomain(),
        ComicsMockDomain(),
        IdentityMockDomain(),
      ],
    );
    session = Session.empty(FileStore(dir));
    tracker = _Tracker();
    await session.signIn(userId: 'u-100', tokens: _tokens('u-100'));
    final dio = backend.createDio()
      ..options.headers['Authorization'] =
          'Bearer ${mintAccessToken('u-100', 1)}';
    bloc = CharacterFavouriteBloc(
      CharacterDetailsRepository(CharacterDetailsApi(dio)),
      FeatureFlowController<CharacterDetailsFlowState>(
        const CharacterDetailsFlowState(characterId: CharacterId(100002)),
      ),
      _Navigator(),
      session,
      EventBus(),
      tracker,
      Monitoring([]),
    );
    await _settle();
  });

  tearDown(() async {
    await Future.wait(saves);
    saves.clear();
    await bloc.close();
    await session.dispose();
    dir.deleteSync(recursive: true);
  });

  int writes(String method) => backend.recentTraffic
      .where(
        (t) => t.method == method && t.path.startsWith('/v1/me/favourites'),
      )
      .length;

  test('T-0067-AC3 a tap handled after another user signed in, before the '
      'bloc heard of it, writes nothing for them', () async {
    // User A saves the favourite and sees "Remove".
    bloc.add(const CharacterFavouriteEvent.toggle());
    await _settle();
    expect(writes('PUT'), 1, reason: 'A saved it');

    // B signs in (in memory, at once); the tap comes in the same turn,
    // before the session's event reaches the bloc.
    bloc.add(const CharacterFavouriteEvent.toggle());
    final switched = session.signIn(
      userId: 'u-101',
      tokens: _tokens('u-101'),
    );
    saves.add(switched);
    await _settle();
    await switched;

    expect(
      writes('DELETE'),
      0,
      reason: 'a DELETE would remove a favourite B never saw',
    );
    expect(writes('PUT'), 1);
    expect(
      tracker.tracked,
      ['character_favourited id=100002'],
      reason: 'only A\'s saved favourite was tracked',
    );
  });

  test('T-0067-AC3 a saved removal tracks nothing and a saved favourite '
      'tracks once', () async {
    bloc.add(const CharacterFavouriteEvent.toggle());
    await _settle();
    bloc.add(const CharacterFavouriteEvent.toggle());
    await _settle();

    expect(writes('PUT'), 1);
    expect(writes('DELETE'), 1);
    expect(tracker.tracked, ['character_favourited id=100002']);
  });

  test('T-0067-AC3 (P-089) the open guard keys on the comic: the same comic '
      'inside the guard is dropped, another one goes through', () async {
    final navigator = _Navigator();
    final details = CharacterDetailsBloc(
      CharacterDetailsRepository(CharacterDetailsApi(backend.createDio())),
      FeatureFlowController<CharacterDetailsFlowState>(
        const CharacterDetailsFlowState(characterId: CharacterId(100002)),
      ),
      navigator,
      Monitoring([]),
    );
    addTearDown(details.close);

    details
      ..add(const CharacterDetailsEvent.openComic(ComicId(7)))
      ..add(const CharacterDetailsEvent.openComic(ComicId(7)))
      ..add(const CharacterDetailsEvent.openComic(ComicId(8)));
    await _settle();

    expect(navigator.opened, [7, 8]);
  });
}
