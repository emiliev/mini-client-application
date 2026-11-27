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
import 'package:store_home/src/domain/repository/store_home_repository.dart';
import 'package:store_home/src/flow/store_home_flow_state.dart';
import 'package:store_home/src/navigator/store_home_navigator.dart';
import 'package:store_home/src/presentation/bloc/open_category.dart';
import 'package:store_home/src/presentation/bloc/store_section_bloc.dart';

part 'banners_bloc.freezed.dart';
part 'banners_event.dart';
part 'banners_state.dart';

/// The banners section: loads `GET v1/store/banners` on its own, and hands a
/// tapped banner over to where it leads: a comic (the app), a category (a
/// page of this flow) or a search (the app).
@injectable
final class BannersBloc
    extends StoreSectionBloc<BannersEvent, BannersState, List<StoreBanner>> {
  BannersBloc(
    this._repository,
    this._flow,
    this._navigator,
    AnalyticsTracker tracker,
    Monitoring monitoring,
  ) : super(
        const BannersState.loading(),
        monitoring: monitoring,
        tracker: tracker,
        section: StoreSection.banners,
      ) {
    on<BannersEvent>(_onEvent);
    add(const BannersEvent.load());
  }

  final StoreHomeRepository _repository;
  final FeatureFlowController<StoreHomeFlowState> _flow;
  final StoreHomeNavigator _navigator;

  Future<void> _onEvent(BannersEvent event, Emitter<BannersState> emit) async {
    switch (event) {
      case _Load():
        await load(emit);
      case _Retry():
        // Only from the error: a second tap finds the section loading.
        if (state is _Failure) {
          await load(emit);
        }
      case _Refresh(:final done):
        await refresh(emit, done);
      case _Open(:final banner):
        if (startOpenGuard(banner.id)) {
          _open(banner);
        }
    }
  }

  void _open(StoreBanner banner) {
    switch (banner.target) {
      case ComicTarget(:final id):
        tracker.itemTapped(section, StoreItemKind.comic, '${id.value}');
        _navigator.openComic(id);
      case CategoryTarget(:final id):
        tracker.itemTapped(section, StoreItemKind.category, id.value);
        _flow.openCategory(OpenCategory(id: id));
      case SearchTarget(:final query):
        tracker.itemTapped(section, StoreItemKind.search, query);
        _navigator.openSearch(query);
    }
  }

  @override
  Future<Result<List<StoreBanner>, ApiFailure>> fetch() =>
      _repository.fetchBanners();

  @override
  bool isEmptyData(List<StoreBanner> data) => data.isEmpty;

  @override
  BannersState loadingState() => const BannersState.loading();

  @override
  BannersState readyState(List<StoreBanner> data) => BannersState.ready(data);

  @override
  BannersState emptyState() => const BannersState.empty();

  @override
  BannersState failureState(ApiFailure error) => BannersState.failure(error);
}
