import 'package:characters_list/src/domain/model/character.dart';
import 'package:characters_list/src/domain/model/character_id.dart';
import 'package:characters_list/src/domain/repository/characters_list_repository.dart';
import 'package:characters_list/src/navigator/characters_list_navigator.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// What the preview page asks for.
sealed class CharacterPreviewEvent {
  const CharacterPreviewEvent();

  /// "See full profile": hand over to the app.
  const factory CharacterPreviewEvent.seeFullProfile() = _SeeFullProfile;
}

final class _SeeFullProfile extends CharacterPreviewEvent {
  const _SeeFullProfile();
}

/// The preview page's bloc. Its state is the character the list loaded (no
/// second request); "See full profile" leaves the feature through the
/// navigator, which only blocs call (plan 01 §4.1).
@injectable
final class CharacterPreviewBloc
    extends McBloc<CharacterPreviewEvent, Character> {
  CharacterPreviewBloc(
    @factoryParam CharacterId id,
    CharactersListRepository repository,
    this._navigator,
    Monitoring monitoring,
  ) : super(repository.loaded(id), monitoring: monitoring) {
    on<CharacterPreviewEvent>((event, emit) {
      switch (event) {
        case _SeeFullProfile():
          _navigator.openCharacter(state.id);
      }
    });
  }

  final CharactersListNavigator _navigator;
}
