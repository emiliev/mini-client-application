// T-0050-AC3 (P-093): the editor bloc's own guards, each pinned on its own.
//
// Since T-0050 the repository pins every write to the session epoch, so a
// feature test through the real auth interceptor can no longer tell a bloc
// guard from the pin: both stop the request. These tests run the real bloc
// and repository over the mocked backend with NO auth interceptor, so the
// bloc's guard is the only thing between a changed session and the wire, and
// the backend's traffic shows whether it held. It is the second place a
// feature test reaches `src/` (R7), like the contract test.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:library_reading_list_editor/src/domain/api/reading_list_editor_api.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_id.dart';
import 'package:library_reading_list_editor/src/domain/repository/reading_list_editor_repository.dart';
import 'package:library_reading_list_editor/src/flow/reading_list_editor_flow_state.dart';
import 'package:library_reading_list_editor/src/navigator/reading_list_editor_navigator.dart';
import 'package:library_reading_list_editor/src/presentation/bloc/reading_list_editor_bloc.dart';
import 'package:library_reading_list_editor/src/presentation/form/reading_list_form.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_library/mc_fixtures_library.dart';
import 'package:mc_forms/mc_forms.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';

final class _Navigator implements ReadingListEditorNavigator {
  final List<Completer<bool>> asked = [];

  @override
  Future<bool> requestSignIn() {
    final answer = Completer<bool>();
    asked.add(answer);
    return answer.future;
  }
}

AuthTokens _tokens(String user) => AuthTokens(
  accessToken: mintAccessToken(user, 1),
  refreshToken: mintRefreshToken(user, 1),
);

/// The real bloc and repository, a real session, the mocked backend, and a
/// `Dio` with the reader's bearer and no auth interceptor.
final class _Harness {
  _Harness._(this.dir, this.backend, this.session, this.flow, this.navigator) {
    final dio = backend.createDio()
      ..options.headers['Authorization'] =
          'Bearer ${mintAccessToken('u-100', 1)}';
    repository = ReadingListEditorRepository(ReadingListEditorApi(dio));
    bloc = ReadingListEditorBloc(
      repository,
      flow,
      navigator,
      session,
      EventBus(),
      Monitoring([]),
    );
  }

  static Future<_Harness> start({
    ReadingListId? editing,
    bool signedIn = true,
    LatencyProfile latency = LatencyProfile.none,
  }) async {
    final dir = Directory.systemTemp.createTempSync('mc_editor_guards');
    final backend = MockBackend(
      domains: const [
        LibraryMockDomain(),
        ComicsMockDomain(),
        IdentityMockDomain(),
      ],
      latency: latency,
    );
    final session = Session.empty(FileStore(dir));
    if (signedIn) {
      await session.signIn(userId: 'u-100', tokens: _tokens('u-100'));
    }
    return _Harness._(
      dir,
      backend,
      session,
      FeatureFlowController<ReadingListEditorFlowState>(
        ReadingListEditorFlowState(editing: editing),
      ),
      _Navigator(),
    );
  }

  final Directory dir;
  final MockBackend backend;
  final Session session;
  final FeatureFlowController<ReadingListEditorFlowState> flow;
  final _Navigator navigator;
  late final ReadingListEditorRepository repository;
  late final ReadingListEditorBloc bloc;

  int requests(String method, String path) => backend.recentTraffic
      .where((t) => t.method == method && t.path == path)
      .length;

  /// Lets the bloc's asynchronous work run to the end.
  Future<void> settle({int rounds = 20}) async {
    for (var i = 0; i < rounds; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  /// Fills the wizard so it can be submitted: a name, one comic, and (when
  /// [reorder] is true) an edit of the comics too.
  Future<void> fill({bool reorder = false}) async {
    await settle();
    bloc.add(const ReadingListEditorEvent.nameChanged('Amber reads'));
    bloc.add(const ReadingListEditorEvent.next());
    final comics = (await repository.searchComics('Amber Ch')).getOrNull()!;
    bloc.add(ReadingListEditorEvent.comicToggled(comics.first));
    bloc.add(const ReadingListEditorEvent.next());
    if (reorder) {
      bloc.add(const ReadingListEditorEvent.comicMoved(0, 1));
    }
    await settle();
  }

  /// The other user takes over in memory, in the same turn as the caller's
  /// next statement: the bloc has not heard of it yet (the session's stream
  /// delivers later).
  void switchUser() =>
      _saves.add(session.signIn(userId: 'u-101', tokens: _tokens('u-101')));

  /// Saves a test did not await: [dispose] awaits them before it deletes the
  /// storage folder (T-0050 D1).
  final List<Future<Object?>> _saves = [];

  Future<void> dispose() async {
    await Future.wait(_saves);
    await bloc.close();
    await session.dispose();
    dir.deleteSync(recursive: true);
  }
}

void main() {
  late _Harness h;

  group('T-0050-AC3 the bloc guards (P-093)', () {
    tearDown(() => h.dispose());

    test('T-0050-AC3 a Finish that the bloc handles after the user switched sends no create (P-093 V01)', () async {
      h = await _Harness.start();
      await h.fill();

      h.switchUser();
      h.bloc.add(const ReadingListEditorEvent.submit());
      await h.settle();

      expect(
        h.requests('POST', '/v1/me/lists'),
        0,
        reason: 'the pre-write epoch check of the create',
      );
    });

    test('T-0050-AC3 a Save that the bloc handles after the user switched sends no first write of an edit (P-093 V02)', () async {
      h = await _Harness.start(editing: const ReadingListId('l-1'));
      await h.fill();
      h.bloc.add(
        const ReadingListEditorEvent.nameChanged('Spider-Verse Basics'),
      );
      await h.settle();

      h.switchUser();
      h.bloc.add(const ReadingListEditorEvent.submit());
      await h.settle();

      expect(
        h.requests('PUT', '/v1/me/lists/l-1'),
        0,
        reason: 'the pre-write epoch check of the details write',
      );
      expect(h.requests('PUT', '/v1/me/lists/l-1/items'), 0);
    });

    test('T-0050-AC3 a switch between the two writes of an edit sends no second write (P-093 V03)', () async {
      // Every answer takes 100 ms, so the first write is still in flight when
      // the user switches.
      h = await _Harness.start(
        editing: const ReadingListId('l-1'),
        latency: const LatencyProfile.slow(Duration(milliseconds: 100)),
      );
      await h.settle(rounds: 100);
      h.bloc
        ..add(const ReadingListEditorEvent.nameChanged('Spider-Verse Basics'))
        ..add(const ReadingListEditorEvent.next())
        ..add(const ReadingListEditorEvent.next())
        ..add(const ReadingListEditorEvent.comicMoved(0, 1));
      await h.settle();
      h.bloc.add(const ReadingListEditorEvent.submit());
      await Future<void>.delayed(const Duration(milliseconds: 30));

      h.switchUser();
      await h.settle(rounds: 200);

      expect(
        h.requests('PUT', '/v1/me/lists/l-1'),
        1,
        reason: 'the first write was sent, for the first user',
      );
      expect(
        h.requests('PUT', '/v1/me/lists/l-1/items'),
        0,
        reason: 'the epoch check between the two writes',
      );
    });

    test('T-0050-AC3 a sign-in the app confirms while nobody is signed in closes the editor with no list and no request (P-093 V19)', () async {
      h = await _Harness.start(signedIn: false);
      await h.settle();
      expect(h.navigator.asked, hasLength(1), reason: 'the editor asked');

      h.navigator.asked.single.complete(true);
      await h.settle();

      expect(h.flow.isCompleted, isTrue);
      expect(h.flow.result, isNull);
      expect(h.backend.recentTraffic, isEmpty);
    });

    test('T-0050-AC3 a double Retry reads the list once (P-093 V20)', () async {
      h = await _Harness.start(editing: const ReadingListId('l-1'));
      h.backend.failNext(
        'GET',
        '/v1/me/lists/l-1',
        const FailureKind.http(500),
      );
      await h.settle();
      expect(h.requests('GET', '/v1/me/lists/l-1'), greaterThanOrEqualTo(1));
      final before = h.requests('GET', '/v1/me/lists/l-1');

      h.bloc
        ..add(const ReadingListEditorEvent.retry())
        ..add(const ReadingListEditorEvent.retry());
      await h.settle();

      expect(h.requests('GET', '/v1/me/lists/l-1'), before + 1);
    });

    test('T-0050-AC3 a session change that arrives while the bloc is closing is not added to it (P-093 V23)', () async {
      h = await _Harness.start();
      await h.settle();

      final errors = <Object>[];
      await runZonedGuarded(() async {
        // The session's event is queued first, then the bloc starts closing
        // in the same turn: the event reaches the listener of a closed bloc.
        h.switchUser();
        await h.bloc.close();
        await h.settle();
      }, (error, _) => errors.add(error));

      expect(errors, isEmpty, reason: 'nothing was added to a closed bloc');
    });
  });

  group('T-0050-AC3 the backend refusals the editor maps to a field (P-093 V21, V22)', () {
    test(
      'T-0050-AC3 the parameter of a 400 names the field the user can change',
      () {
        expect(ReadingListFields.ofParameter('name'), ReadingListFields.name);
        expect(
          ReadingListFields.ofParameter('description'),
          ReadingListFields.description,
        );
        expect(
          ReadingListFields.ofParameter('comicIds'),
          ReadingListFields.comics,
        );
        expect(ReadingListFields.ofParameter('body'), isNull);
        expect(ReadingListFields.ofParameter(null), isNull);
      },
    );

    test('T-0050-AC3 too_many_comics reads as the comics limit, any other code as not accepted', () {
      expect(
        serverError('too_many_comics'),
        const FieldError(
          ValidationCode.aboveMax,
          max: ReadingListRules.maxComics,
        ),
      );
      expect(
        serverError('duplicate_name'),
        const FieldError(ValidationCode.invalid),
      );
      expect(serverError(null), const FieldError(ValidationCode.invalid));
    });
  });
}
