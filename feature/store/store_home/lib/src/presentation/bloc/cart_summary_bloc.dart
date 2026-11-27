import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_session/mc_session.dart';
import 'package:store_home/src/domain/model/store.dart';
import 'package:store_home/src/domain/model/store_analytics.dart';
import 'package:store_home/src/domain/repository/store_home_repository.dart';
import 'package:store_home/src/navigator/store_home_navigator.dart';
import 'package:store_home/src/presentation/bloc/store_section_bloc.dart';

part 'cart_summary_bloc.freezed.dart';
part 'cart_summary_event.dart';
part 'cart_summary_state.dart';

/// The cart section: the signed-in user's item count and total
/// (`GET v1/me/cart`), which opens the cart.
///
/// - **Signed out** the summary is hidden: the section offers to sign in
///   and sends nothing. A tap asks the app (`requestSignIn()`) and waits;
///   whatever the answer, the session decides what shows next.
/// - **The session decides.** It follows `SessionReader.authState`: a
///   sign-in, a sign-out or a user switch anywhere reloads the section for
///   the session now current, once per session epoch.
/// - **Every await is a session boundary** (F-0040 fact 21): a cart read
///   started for one session and answered under another is dropped before
///   any state is written, and the request itself is pinned to its epoch
///   (T-0050), so it never goes out with another user's bearer.
@injectable
final class CartSummaryBloc
    extends StoreSectionBloc<CartSummaryEvent, CartSummaryState, CartSummary> {
  CartSummaryBloc(
    this._repository,
    this._navigator,
    this._session,
    AnalyticsTracker tracker,
    Monitoring monitoring,
  ) : super(
        const CartSummaryState.loading(),
        monitoring: monitoring,
        tracker: tracker,
        section: StoreSection.cart,
      ) {
    on<CartSummaryEvent>(_onEvent);
    _sessionChanges = _session.authState.listen(
      (_) => add(const _SessionChanged()),
    );
    add(const CartSummaryEvent.load());
  }

  final StoreHomeRepository _repository;
  final StoreHomeNavigator _navigator;
  final SessionReader _session;
  late final StreamSubscription<AuthStatus> _sessionChanges;

  /// The session epoch the section last started to show (loaded, or showed
  /// signed out for). A session event for this same epoch changes nothing.
  int? _shownEpoch;

  Future<void> _onEvent(
    CartSummaryEvent event,
    Emitter<CartSummaryState> emit,
  ) async {
    switch (event) {
      case _Load():
        await _show(emit);
      case _Retry():
        if (state is _Failure) {
          await _show(emit);
        }
      case _Refresh(:final done):
        if (_session.isSignedIn) {
          await refresh(emit, done);
        } else {
          done.complete();
        }
      case _SessionChanged():
        if (_session.epoch != _shownEpoch) {
          await _show(emit);
        }
      case _SignIn():
        await _signIn(emit);
      case _Open():
        if (startOpenGuard(StoreItemKind.cart)) {
          tracker.itemTapped(section, StoreItemKind.cart, 'summary');
          _navigator.openCart();
        }
    }
  }

  /// Shows the section for the session now current: signed out, or its cart.
  Future<void> _show(Emitter<CartSummaryState> emit) async {
    _shownEpoch = _session.epoch;
    if (!_session.isSignedIn) {
      // A read still on its way is dropped by [fetch]: its session is gone.
      emit(const CartSummaryState.signedOut());
      return;
    }
    await load(emit);
  }

  Future<void> _signIn(Emitter<CartSummaryState> emit) async {
    // One sign-in at a time: a second tap finds it signing in.
    if (state is! _SignedOut) {
      return;
    }
    emit(const CartSummaryState.signingIn());
    await _navigator.requestSignIn();
    if (isClosed) {
      return;
    }
    // The session, not the answer, decides. A sign-in reloaded the section
    // already if its event came first; otherwise it loads now, once.
    if (_session.epoch != _shownEpoch || state is _SigningIn) {
      await _show(emit);
    }
  }

  @override
  Future<Result<CartSummary, ApiFailure>?> fetch() async {
    final epoch = _session.epoch;
    final result = await _repository.fetchCart(epoch: epoch);
    // An answer for a session that is gone is dropped; that session's
    // change reloads the section (or already has).
    return _session.epoch == epoch ? result : null;
  }

  @override
  bool isEmptyData(CartSummary data) => data.itemCount == 0;

  @override
  CartSummaryState loadingState() => const CartSummaryState.loading();

  @override
  CartSummaryState readyState(CartSummary data) => CartSummaryState.ready(data);

  @override
  CartSummaryState emptyState() => const CartSummaryState.empty();

  @override
  CartSummaryState failureState(ApiFailure error) =>
      CartSummaryState.failure(error);

  @override
  Future<void> close() {
    // Not awaited: a cancel future is made in the root zone and never
    // completes under a widget test's fake async (F-0052 trap 1).
    unawaited(_sessionChanges.cancel());
    return super.close();
  }
}
