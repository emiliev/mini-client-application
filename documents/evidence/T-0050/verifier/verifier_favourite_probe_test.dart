// T-0050 Verifier probes on the favourite guard. Not committed.
import 'dart:io';

import 'package:comics_details/src/domain/api/comics_details_api.dart';
import 'package:comics_details/src/domain/model/character_id.dart';
import 'package:comics_details/src/domain/model/comic_id.dart';
import 'package:comics_details/src/domain/model/creator_id.dart';
import 'package:comics_details/src/domain/repository/comics_details_repository.dart';
import 'package:comics_details/src/flow/comics_details_flow_state.dart';
import 'package:comics_details/src/navigator/comics_details_navigator.dart';
import 'package:comics_details/src/presentation/bloc/comic_favourite_bloc.dart';
import 'package:dio/dio.dart';
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
    dir = Directory.systemTemp.createTempSync('v_fav');
    backend = MockBackend(
      domains: const [ComicsMockDomain(), IdentityMockDomain()],
    );
    session = Session.empty(FileStore(dir));
    await session.signIn(userId: 'u-100', tokens: _tokens('u-100'));
    final dio = backend.createDio();
    // A bearer of whoever is signed in now, read at send time (an unpinned
    // stand-in for the auth interceptor, so writes land on the right user).
    dio.interceptors.add(
      InterceptorsWrapperLike((o) {
        final t = session.accessToken;
        if (t != null) {
          o.headers['Authorization'] = 'Bearer $t';
        }
      }),
    );
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

  test('VP1 reload lands first, then the tap: B can write', () async {
    session.signIn(userId: 'u-101', tokens: _tokens('u-101')).ignore();
    await _settle();
    bloc.add(const ComicFavouriteEvent.toggle());
    await _settle();
    expect(writes('PUT'), 1);
    expect(bloc.state, const ComicFavouriteState.ready(favourite: true));
  });

  test('VP2 race drops the tap, then a later tap works', () async {
    bloc.add(const ComicFavouriteEvent.toggle());
    session.signIn(userId: 'u-101', tokens: _tokens('u-101')).ignore();
    await _settle();
    expect(writes('PUT') + writes('DELETE'), 0, reason: 'dropped');
    bloc.add(const ComicFavouriteEvent.toggle());
    await _settle();
    expect(writes('PUT'), 1, reason: 'a legitimate tap after the reload');
  });

  test('VP3 same-user re-sign-in (epoch bump, no event): not stuck', () async {
    session.signIn(userId: 'u-100', tokens: _tokens('u-100')).ignore();
    await _settle();
    bloc.add(const ComicFavouriteEvent.toggle());
    await _settle();
    final first = writes('PUT');
    bloc.add(const ComicFavouriteEvent.toggle());
    await _settle();
    // ignore: avoid_print
    print(
      'VP3 first tap PUTs=$first, after second tap '
      'PUT=${writes('PUT')} DELETE=${writes('DELETE')} state=${bloc.state}',
    );
    expect(writes('PUT') + writes('DELETE'), greaterThanOrEqualTo(1));
  });

  test('VP4 sign-out then tap: no write, shows not a favourite', () async {
    session.signOut().ignore();
    await _settle();
    bloc.add(const ComicFavouriteEvent.toggle());
    await _settle();
    expect(writes('PUT') + writes('DELETE'), 0);
  });
}

final class InterceptorsWrapperLike extends Interceptor {
  InterceptorsWrapperLike(this.f);
  final void Function(RequestOptions) f;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    f(options);
    handler.next(options);
  }
}
