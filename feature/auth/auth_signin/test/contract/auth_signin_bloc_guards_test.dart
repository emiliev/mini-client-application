// T-0066-AC1: the bloc's own guards, each pinned on its own over the real
// backend (the identity fixture) and a real session: one request per submit,
// nothing after a sign-in, no leaving mid-request, and a closed bloc stays
// quiet. A third place a feature test reaches `src/` (R7), like the contract
// test.
import 'dart:io';

import 'package:auth_signin/src/domain/model/demo_account.dart';
import 'package:auth_signin/src/domain/model/sign_in_failure.dart';
import 'package:auth_signin/src/domain/model/sign_in_result.dart';
import 'package:auth_signin/src/domain/repository/auth_signin_repository.dart';
import 'package:auth_signin/src/flow/auth_signin_flow_state.dart';
import 'package:auth_signin/src/presentation/bloc/auth_signin_bloc.dart';
import 'package:auth_signin/src/presentation/form/auth_signin_form.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_forms/mc_forms.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';

final class _Harness {
  _Harness._(this.dir, this.backend, this.session, this.flow) {
    final auth = AuthApi(backend.createDio(), session, session);
    bloc = AuthSignInBloc(AuthSignInRepository(auth), flow, Monitoring([]));
    results = [];
    flow.completions.listen(results.add);
  }

  static _Harness start({Duration latency = Duration.zero}) {
    final dir = Directory.systemTemp.createTempSync('mc_sign_in_guards');
    final backend = MockBackend(
      domains: const [IdentityMockDomain()],
      latency: latency == Duration.zero
          ? LatencyProfile.none
          : LatencyProfile.slow(latency),
    );
    return _Harness._(
      dir,
      backend,
      Session.empty(FileStore(dir)),
      FeatureFlowController<AuthSignInFlowState>(const AuthSignInFlowState()),
    );
  }

  final Directory dir;
  final MockBackend backend;
  final Session session;
  final FeatureFlowController<AuthSignInFlowState> flow;
  late final AuthSignInBloc bloc;
  late final List<Object?> results;

  int get signInRequests => backend.recentTraffic
      .where((t) => t.method == 'POST' && t.path == '/v1/auth/sign-in')
      .length;

  void fill({String password = 'marvelous'}) {
    bloc
      ..add(AuthSignInEvent.emailChanged(fixtureUsers.first.email))
      ..add(AuthSignInEvent.passwordChanged(password));
  }

  /// Waits until [done] holds, polling the event loop (no wall-clock guess).
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 500 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(done(), isTrue, reason: 'the condition was never reached');
  }

  /// Lets queued work run, so "nothing more happened" has had its chance.
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  Future<void> dispose() async {
    await bloc.close();
    await session.signOut();
    await session.dispose();
    await dir.delete(recursive: true);
  }
}

void main() {
  late _Harness h;

  tearDown(() => h.dispose());

  test('T-0066-AC1 three submits in one turn send one request and complete '
      'once', () async {
    h = _Harness.start(latency: const Duration(milliseconds: 30))..fill();
    await h.settle();

    h.bloc
      ..add(const AuthSignInEvent.submit())
      ..add(const AuthSignInEvent.submit())
      ..add(const AuthSignInEvent.submit());
    await h.until(() => h.results.isNotEmpty);
    await h.settle();

    expect(h.signInRequests, 1);
    expect(h.results, [SignInResult.signedIn]);
    expect(h.session.userId, fixtureUsers.first.id);
  });

  test('T-0066-AC1 after the sign-in, a further submit sends nothing and '
      'Not now does not turn it into a cancel', () async {
    h = _Harness.start()..fill();
    await h.settle();
    h.bloc.add(const AuthSignInEvent.submit());
    await h.until(() => h.results.isNotEmpty);

    h.bloc
      ..add(const AuthSignInEvent.submit())
      ..add(const AuthSignInEvent.notNow());
    await h.settle();

    expect(h.signInRequests, 1);
    expect(h.results, [SignInResult.signedIn]);
    expect(h.bloc.state.isBusy, isTrue, reason: 'busy until the page leaves');
  });

  test('T-0066-AC1 Not now while the request is on its way is ignored, so a '
      'sign-in is never answered as cancelled', () async {
    h = _Harness.start(latency: const Duration(milliseconds: 30))..fill();
    await h.settle();

    h.bloc
      ..add(const AuthSignInEvent.submit())
      ..add(const AuthSignInEvent.notNow());
    await h.until(() => h.results.isNotEmpty);
    await h.settle();

    expect(h.results, [SignInResult.signedIn]);
  });

  test('T-0066-AC1 Not now on an idle form completes as cancelled and '
      'sends nothing', () async {
    h = _Harness.start();
    await h.settle();

    h.bloc.add(const AuthSignInEvent.notNow());
    await h.settle();

    expect(h.results, [SignInResult.cancelled]);
    expect(h.signInRequests, 0);
    expect(h.session.isSignedIn, isFalse);
  });

  test('T-0066-AC1 a failed submit shows the failure, an edit clears it, and '
      'the retry sends a second request', () async {
    h = _Harness.start()..fill(password: 'not-it');
    await h.settle();

    h.bloc.add(const AuthSignInEvent.submit());
    await h.until(() => h.bloc.state.failure != null);
    expect(h.bloc.state.failure, isA<InvalidCredentials>());
    expect(h.bloc.state.isBusy, isFalse);
    expect(h.results, isEmpty);

    h.bloc.add(const AuthSignInEvent.passwordChanged('marvelous'));
    await h.until(() => h.bloc.state.failure == null);

    h.bloc.add(const AuthSignInEvent.submit());
    await h.until(() => h.results.isNotEmpty);
    expect(h.signInRequests, 2);
    expect(h.results, [SignInResult.signedIn]);
  });

  test(
    'T-0066-AC1 an invalid form sends nothing and touches every field',
    () async {
      h = _Harness.start();
      await h.settle();

      h.bloc.add(const AuthSignInEvent.submit());
      await h.settle();

      final form = h.bloc.state.form;
      expect(h.signInRequests, 0);
      expect(
        form.fieldOf<String>(SignInFields.email).visibleError,
        const FieldError(ValidationCode.required),
      );
      expect(
        form.fieldOf<String>(SignInFields.password).visibleError,
        const FieldError(ValidationCode.required),
      );
      expect(h.results, isEmpty);
    },
  );

  test('T-0066-AC1 a bloc closed while the request is on its way completes '
      'nothing, throws nothing, and undoes the sign-in that lands', () async {
    h = _Harness.start(latency: const Duration(milliseconds: 30))..fill();
    await h.settle();

    h.bloc.add(const AuthSignInEvent.submit());
    await h.until(() => h.bloc.state.form.isSubmitting);
    await h.bloc.close();
    await h.until(
      () => h.backend.recentTraffic.any((t) => t.path == '/v1/auth/sign-out'),
    );
    await h.settle();

    expect(h.results, isEmpty, reason: 'the flow was gone');
    expect(h.session.isSignedIn, isFalse, reason: 'leaving cancels');
  });

  test('T-0066-AC1 a demo account fills both fields, and is ignored while a '
      'request runs', () async {
    h = _Harness.start(latency: const Duration(milliseconds: 30));
    await h.settle();
    final reader = fixtureUsers.first;
    final collector = fixtureUsers.last;

    h.bloc.add(
      AuthSignInEvent.useDemoAccount(
        DemoAccount(
          email: reader.email,
          password: reader.password,
          displayName: reader.displayName,
        ),
      ),
    );
    await h.settle();
    expect(
      h.bloc.state.form.values.get<String>(SignInFields.email),
      reader.email,
    );
    expect(
      h.bloc.state.form.values.get<String>(SignInFields.password),
      reader.password,
    );

    h.bloc.add(const AuthSignInEvent.submit());
    h.bloc.add(
      AuthSignInEvent.useDemoAccount(
        DemoAccount(
          email: collector.email,
          password: collector.password,
          displayName: collector.displayName,
        ),
      ),
    );
    await h.until(() => h.results.isNotEmpty);
    expect(h.session.userId, reader.id);
    expect(
      h.bloc.state.form.values.get<String>(SignInFields.email),
      reader.email,
    );
  });
}
