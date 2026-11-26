import 'package:comics_details/src/domain/model/character_id.dart';
import 'package:comics_details/src/domain/model/comic.dart';
import 'package:comics_details/src/domain/model/comic_dto.dart';
import 'package:comics_details/src/domain/model/comic_id.dart';
import 'package:comics_details/src/domain/model/creator_id.dart';
import 'package:mc_formatters/mc_formatters.dart';
import 'package:mc_media/mc_media.dart';

/// Wire to domain. A value the contract does not allow (an unknown variant,
/// role or currency, a day that is not `YYYY-MM-DD`) throws a
/// [FormatException], which the repository's `apiCall` turns into
/// `ApiMalformed`.
extension ComicDtoMapper on ComicDto {
  /// The comic with its [cast], which the backend serves separately.
  Comic toDomain({required List<CastMember> cast}) => Comic(
    id: ComicId(id),
    title: title,
    issueNumber: issueNumber,
    description: description,
    cover: cover.toDomain(),
    price: price.toDomain(),
    pageCount: pageCount,
    releaseDate: parseDay(releaseDate),
    creators: [
      for (final credit in creators)
        Credit(
          id: CreatorId(credit.id),
          name: credit.name,
          role: CreatorRole.fromWire(credit.role),
        ),
    ],
    cast: cast,
  );
}

extension ImageDtoMapper on ImageDto {
  ApiImage toDomain() =>
      ApiImage(path: path, variant: ImageVariant.fromWire(variant));
}

extension PriceDtoMapper on PriceDto {
  Money toDomain() => Money(
    amountCents,
    Currency.values.firstWhere(
      (c) => c.code == currency,
      orElse: () => throw FormatException('Unknown currency "$currency"'),
    ),
  );
}

extension CastMemberDtoMapper on CastMemberDto {
  CastMember toDomain() => CastMember(
    id: CharacterId(id),
    name: name,
    image: thumbnail.toDomain(),
  );
}

final RegExp _day = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// A `YYYY-MM-DD` day as midnight UTC; anything else, or a day that does not
/// exist (`2020-02-30`), is a [FormatException].
DateTime parseDay(String text) {
  final match = _day.firstMatch(text);
  if (match == null) {
    throw FormatException('Not a YYYY-MM-DD day', text);
  }
  final [year, month, day] = [
    for (var g = 1; g <= 3; g++) int.parse(match.group(g)!),
  ];
  final date = DateTime.utc(year, month, day);
  if (date.month != month || date.day != day) {
    throw FormatException('No such day', text);
  }
  return date;
}
