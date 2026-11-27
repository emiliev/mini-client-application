import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:store_home/src/domain/model/store.dart';
import 'package:store_home/src/domain/model/store_analytics.dart';
import 'package:store_home/src/domain/model/store_clock.dart';
import 'package:store_home/src/domain/repository/store_home_repository.dart';
import 'package:store_home/src/navigator/store_home_navigator.dart';
import 'package:store_home/src/presentation/bloc/store_section_bloc.dart';

part 'deals_bloc.freezed.dart';
part 'deals_event.dart';
part 'deals_state.dart';

/// The deals section: loads `GET v1/store/deals` on its own, with the time
/// its countdowns are read against (the injected [StoreClock]), and hands a
/// tapped deal's comic over to the app.
@injectable
final class DealsBloc
    extends StoreSectionBloc<DealsEvent, DealsState, List<Deal>> {
  DealsBloc(
    this._repository,
    this._navigator,
    this._clock,
    AnalyticsTracker tracker,
    Monitoring monitoring,
  ) : super(
        const DealsState.loading(),
        monitoring: monitoring,
        tracker: tracker,
        section: StoreSection.deals,
      ) {
    on<DealsEvent>(_onEvent);
    add(const DealsEvent.load());
  }

  final StoreHomeRepository _repository;
  final StoreHomeNavigator _navigator;
  final StoreClock _clock;

  Future<void> _onEvent(DealsEvent event, Emitter<DealsState> emit) async {
    switch (event) {
      case _Load():
        await load(emit);
      case _Retry():
        if (state is _Failure) {
          await load(emit);
        }
      case _Refresh(:final done):
        await refresh(emit, done);
      case _Open(:final deal):
        final id = deal.product.id;
        if (startOpenGuard(id.value)) {
          tracker.itemTapped(section, StoreItemKind.comic, '${id.value}');
          _navigator.openComic(id);
        }
    }
  }

  @override
  Future<Result<List<Deal>, ApiFailure>> fetch() => _repository.fetchDeals();

  @override
  bool isEmptyData(List<Deal> data) => data.isEmpty;

  @override
  DealsState loadingState() => const DealsState.loading();

  @override
  DealsState readyState(List<Deal> data) =>
      DealsState.ready(data, _clock.now());

  @override
  DealsState emptyState() => const DealsState.empty();

  @override
  DealsState failureState(ApiFailure error) => DealsState.failure(error);
}
