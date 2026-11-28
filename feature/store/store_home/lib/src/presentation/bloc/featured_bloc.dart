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
import 'package:store_home/src/navigator/store_home_navigator.dart';
import 'package:store_home/src/presentation/bloc/store_section_bloc.dart';

part 'featured_bloc.freezed.dart';
part 'featured_event.dart';
part 'featured_state.dart';

/// The featured section: loads `GET v1/store/featured` on its own, and hands
/// a tapped product's comic over to the app. It exists only while the flag
/// `store.home_featured` is on: the page does not build it otherwise, so
/// this bloc is never created and nothing is requested.
@injectable
final class FeaturedBloc
    extends StoreSectionBloc<FeaturedEvent, FeaturedState, List<Product>> {
  FeaturedBloc(
    this._repository,
    this._navigator,
    AnalyticsTracker tracker,
    Monitoring monitoring,
  ) : super(
        const FeaturedState.loading(),
        monitoring: monitoring,
        tracker: tracker,
        section: StoreSection.featured,
      ) {
    // Idle until the page is shown: the page adds `load` (a visit).
    on<FeaturedEvent>(_onEvent);
  }

  final StoreHomeRepository _repository;
  final StoreHomeNavigator _navigator;

  Future<void> _onEvent(
    FeaturedEvent event,
    Emitter<FeaturedState> emit,
  ) async {
    switch (event) {
      case _Load():
        await load(emit);
      case _Retry():
        if (state is _Failure) {
          await load(emit);
        }
      case _Refresh(:final done):
        await refresh(emit, done);
      case _Open(:final product):
        // mcgen:keep featured.open
        if (startOpenGuard(product.id.value)) {
          tracker.itemTapped(
            section,
            StoreItemKind.comic,
            '${product.id.value}',
          );
          _navigator.openComic(product.id);
        }
      // mcgen:end featured.open
    }
  }

  @override
  Future<Result<List<Product>, ApiFailure>> fetch() =>
      _repository.fetchFeatured();

  @override
  bool isEmptyData(List<Product> data) => data.isEmpty;

  @override
  FeaturedState loadingState() => const FeaturedState.loading();

  @override
  FeaturedState readyState(List<Product> data) => FeaturedState.ready(data);

  @override
  FeaturedState emptyState() => const FeaturedState.empty();

  @override
  FeaturedState failureState(ApiFailure error) => FeaturedState.failure(error);
}
