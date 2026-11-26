import 'package:comics_details/src/domain/model/comic.dart';
import 'package:comics_details/src/domain/model/comic_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'comics_details_flow_state.freezed.dart';

/// What the flow shows, not which page is on top (plan 01 §4.1): the comic
/// it opened on, and the comic whose cover is open full size. Pure Dart, so
/// the blocs that update it stay Flutter-free (R15).
@freezed
abstract class ComicsDetailsFlowState with _$ComicsDetailsFlowState {
  const factory ComicsDetailsFlowState({
    /// The comic the flow opened on (`/comics/:id`); the flow starts from
    /// the id alone (plan 01 §4.4).
    required ComicId comicId,

    /// The loaded comic whose cover page is open: the cover page needs no
    /// second request, and the repository stays stateless.
    Comic? cover,
  }) = _ComicsDetailsFlowState;
}
