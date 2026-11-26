import 'package:comics_details/src/domain/model/character_id.dart';
import 'package:comics_details/src/domain/model/comic_id.dart';
import 'package:comics_details/src/domain/model/creator_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mc_formatters/mc_formatters.dart';
import 'package:mc_media/mc_media.dart';

part 'comic.freezed.dart';

/// A comic as this page shows it, with its cast resolved to names and art.
/// Domain model: no JSON, so a bare `@freezed` (R30 is about models with
/// JSON); the wire shape is `ComicDto`.
@freezed
abstract class Comic with _$Comic {
  const factory Comic({
    required ComicId id,
    required String title,
    required int issueNumber,
    required String description,
    required ApiImage cover,
    required Money price,
    required int pageCount,

    /// The release day, at midnight UTC.
    required DateTime releaseDate,
    required List<Credit> creators,
    required List<CastMember> cast,
  }) = _Comic;
}

/// Someone credited on the comic, in the contract's role order.
@freezed
abstract class Credit with _$Credit {
  const factory Credit({
    required CreatorId id,
    required String name,
    required CreatorRole role,
  }) = _Credit;
}

/// A character in the comic's cast.
@freezed
abstract class CastMember with _$CastMember {
  const factory CastMember({
    required CharacterId id,
    required String name,
    required ApiImage image,
  }) = _CastMember;
}

/// What a creator did on the comic (`mc_fixtures_comics` CONTRACT.md).
enum CreatorRole {
  writer('writer'),
  penciller('penciller'),
  inker('inker'),
  colorist('colorist'),
  letterer('letterer'),
  coverArtist('cover_artist');

  const CreatorRole(this.wireName);

  /// The name on the wire.
  final String wireName;

  /// The role named [name]; an unknown name is a [FormatException], which
  /// the repository's `apiCall` turns into `ApiMalformed`.
  static CreatorRole fromWire(String name) => values.firstWhere(
    (role) => role.wireName == name,
    orElse: () => throw FormatException('Unknown creator role "$name"'),
  );
}
