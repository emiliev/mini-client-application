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
import 'package:store_home/src/presentation/bloc/open_category.dart';
import 'package:store_home/src/presentation/bloc/store_section_bloc.dart';

part 'categories_bloc.freezed.dart';
part 'categories_event.dart';
part 'categories_state.dart';

/// The categories section: loads `GET v1/store/categories` on its own, and
/// opens a tapped category's page inside the flow.
@injectable
final class CategoriesBloc
    extends
        StoreSectionBloc<
          CategoriesEvent,
          CategoriesState,
          List<StoreCategory>
        > {
  CategoriesBloc(
    this._repository,
    this._flow,
    AnalyticsTracker tracker,
    Monitoring monitoring,
  ) : super(
        const CategoriesState.loading(),
        monitoring: monitoring,
        tracker: tracker,
        section: StoreSection.categories,
      ) {
    // Idle until the page is shown: the page adds `load` (a visit).
    on<CategoriesEvent>(_onEvent);
  }

  final StoreHomeRepository _repository;
  final FeatureFlowController<StoreHomeFlowState> _flow;

  Future<void> _onEvent(
    CategoriesEvent event,
    Emitter<CategoriesState> emit,
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
      case _Open(:final category):
        // mcgen:keep categories.open
        if (startOpenGuard(category.id.value)) {
          tracker.itemTapped(
            section,
            StoreItemKind.category,
            category.id.value,
          );
          _flow.openCategory(
            OpenCategory(id: category.id, name: category.name),
          );
        }
      // mcgen:end categories.open
    }
  }

  @override
  Future<Result<List<StoreCategory>, ApiFailure>> fetch() =>
      _repository.fetchCategories();

  @override
  bool isEmptyData(List<StoreCategory> data) => data.isEmpty;

  @override
  CategoriesState loadingState() => const CategoriesState.loading();

  @override
  CategoriesState readyState(List<StoreCategory> data) =>
      CategoriesState.ready(data);

  @override
  CategoriesState emptyState() => const CategoriesState.empty();

  @override
  CategoriesState failureState(ApiFailure error) =>
      CategoriesState.failure(error);
}
