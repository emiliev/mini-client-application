import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:store_home/src/domain/model/store_analytics.dart';

/// How long after a hand-over a second hand-over of the same item is
/// ignored: the second tap of a double tap (P-089). The same value as the
/// other exemplars' open guard.
const Duration openGuard = Duration(milliseconds: 500);

/// The shape every section bloc of a dashboard shares (DB archetype,
/// F-0056). One bloc per section, each with its own events and its own
/// freezed state (`loading`, `ready`, `empty`, `failure`, plus what a
/// section adds): this base holds only the mechanics, so the five sections
/// behave alike and none can affect another.
///
/// - **[load]** shows the section's loading state, fetches, and shows
///   `ready`, `empty` or `failure`. **Retry** is a [load] of this section
///   only. **Pull to refresh** is a [refresh]: the shown state stays until the
///   answer lands.
/// - **The newest answer wins.** Every load bumps a generation; an answer is
///   applied only if no load started after it, so a refresh racing an
///   in-flight load (or the other way round) ends on the latest request's
///   answer, whichever arrives first (F-0046 fact 7). [fetch] may also
///   answer null to drop an answer for a session that is gone (the cart).
/// - **`store_section_viewed`** is tracked once per bloc, that is once per
///   visit of the page, the first time the section is `ready`: not when it
///   failed or is empty, and after a Retry that succeeds.
///
/// [E] is the section's event type, [S] its state, [T] what it fetches.
/// Pure Dart (R15).
abstract base class StoreSectionBloc<E, S, T> extends McBloc<E, S> {
  StoreSectionBloc(
    super.initialState, {
    required super.monitoring,
    required this.tracker,
    required this.section,
  });

  /// The blocs' analytics port (`mc_analytics`' `Analytics`).
  final AnalyticsTracker tracker;

  /// Which section this is (the analytics `section`).
  final StoreSection section;

  int _generation = 0;
  bool _viewed = false;
  Timer? _openGuard;
  Object? _openTarget;

  /// The section's data. Null drops the answer without writing any state:
  /// it belongs to something that has changed since (the cart's session).
  Future<Result<T, ApiFailure>?> fetch();

  /// Whether [data] is the section's empty case.
  bool isEmptyData(T data);

  S loadingState();

  S readyState(T data);

  S emptyState();

  S failureState(ApiFailure error);

  /// Loads the section and shows the answer, unless a later load started
  /// meanwhile. With [keepShown] the current state stays until then (pull to
  /// refresh); otherwise the loading state shows at once (first load,
  /// Retry, a new session).
  Future<void> load(Emitter<S> emit, {bool keepShown = false}) async {
    final generation = ++_generation;
    if (!keepShown) {
      emit(loadingState());
    }
    final result = await fetch();
    // Every await is a boundary: only the newest load may write.
    if (result == null || generation != _generation || isClosed) {
      return;
    }
    result.fold((data) {
      if (isEmptyData(data)) {
        emit(emptyState());
        return;
      }
      emit(readyState(data));
      if (!_viewed) {
        _viewed = true;
        tracker.sectionViewed(section);
      }
    }, (error) => emit(failureState(error)));
  }

  /// Pull to refresh: [load] keeping the shown state, then completes [done]
  /// (the refresh control closes), also when a later load won.
  Future<void> refresh(Emitter<S> emit, Completer<void> done) async {
    try {
      await load(emit, keepShown: true);
    } finally {
      done.complete();
    }
  }

  /// False while a hand-over of the same [target] still guards (the second
  /// tap of a double tap); else starts the guard for it. Another target goes
  /// through at once.
  bool startOpenGuard(Object target) {
    if ((_openGuard?.isActive ?? false) && _openTarget == target) {
      return false;
    }
    _openGuard?.cancel();
    _openGuard = Timer(openGuard, () {});
    _openTarget = target;
    return true;
  }

  @override
  Future<void> close() {
    _openGuard?.cancel();
    return super.close();
  }
}
