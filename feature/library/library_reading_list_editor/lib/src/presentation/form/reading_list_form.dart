import 'package:library_reading_list_editor/src/domain/model/reading_list.dart';
import 'package:library_reading_list_editor/src/domain/repository/reading_list_editor_repository.dart';
import 'package:mc_forms/mc_forms.dart';

/// The wizard's field names (one form over all three steps, `mc_forms`).
abstract final class ReadingListFields {
  static const String name = 'name';
  static const String description = 'description';
  static const String visibility = 'visibility';
  static const String comics = 'comics';

  /// The form field a `400`'s `parameter` names (`mc_fixtures_library`
  /// CONTRACT.md, "Validation"), or null for one the user cannot change (the
  /// editor only ever sends a valid visibility; `body`).
  static String? ofParameter(String? parameter) => switch (parameter) {
    'name' => name,
    'description' => description,
    'comicIds' => comics,
    _ => null,
  };
}

/// The backend's rules (`mc_fixtures_library` CONTRACT.md, "Validation"),
/// checked as the user types so a valid wizard is a valid request. Lengths
/// count what a reader sees as one character, on both sides.
abstract final class ReadingListRules {
  /// A name has 1 to 60 characters after trimming.
  static const int nameMaxLength = 60;

  /// A description has at most 280 characters (not trimmed).
  static const int descriptionMaxLength = 280;

  /// A list has at most 100 comics. A new list needs at least one (P1-20); an
  /// edited list only when its comics change, so a list that is empty on the
  /// backend can still be renamed.
  static const int maxComics = 100;
}

/// The step ids, in order. Step pages and the flow state count them 0 to 2.
abstract final class ReadingListSteps {
  static const String details = 'details';
  static const String comics = 'comics';
  static const String review = 'review';
}

/// What the editor shows under a field the backend refused (its `error.code`):
/// the comics' limit, or "this value was not accepted". The only refusal a
/// valid wizard can meet is `duplicate_name` (the user's names are unique).
FieldError serverError(String? code) => code == 'too_many_comics'
    ? const FieldError(
        ValidationCode.aboveMax,
        max: ReadingListRules.maxComics,
      )
    : const FieldError(ValidationCode.invalid);

String _trimmedName(String? value) => (value ?? '').trim();

/// Applies [rule] to the trimmed text, as the backend trims a name.
Validator<String> _trimmed(Validator<String> rule) =>
    (value) => rule(value?.trim());

/// More than [max] items fails with [ValidationCode.aboveMax].
Validator<List<T>> _atMost<T>(int max) =>
    (value) => value != null && value.length > max
    ? FieldError(ValidationCode.aboveMax, max: max)
    : null;

/// At least one comic: always for a new list ([saved] null); for an edited
/// list only once its comics differ from what the backend holds.
Validator<List<PickedComic>> _comicsRequired(ReadingList? saved) {
  final required = Validators.required<List<PickedComic>>();
  if (saved == null) {
    return required;
  }
  final savedIds = comicIdsOf(saved.comics).join(',');
  return (value) => comicIdsOf(value ?? const []).join(',') == savedIds
      ? null
      : required(value);
}

/// The three steps over one form: details (name, description, visibility),
/// comics, and order and review (it reorders the comics field; no fields of
/// its own). [saved] pre-fills every step in edit mode.
List<WizardStep> readingListSteps({ReadingList? saved}) => [
  WizardStep(
    ReadingListSteps.details,
    fields: [
      FieldDef<String>(
        ReadingListFields.name,
        initial: saved?.name ?? '',
        validators: [
          Validators.required<String>(),
          _trimmed(Validators.maxLength(ReadingListRules.nameMaxLength)),
        ],
      ),
      FieldDef<String>(
        ReadingListFields.description,
        initial: saved?.description ?? '',
        validators: [
          Validators.maxLength(ReadingListRules.descriptionMaxLength),
        ],
      ),
      FieldDef<ReadingListVisibility>(
        ReadingListFields.visibility,
        initial: saved?.visibility ?? ReadingListVisibility.private,
      ),
    ],
  ),
  WizardStep(
    ReadingListSteps.comics,
    fields: [
      FieldDef<List<PickedComic>>(
        ReadingListFields.comics,
        initial: saved?.comics ?? const [],
        validators: [
          _comicsRequired(saved),
          _atMost<PickedComic>(ReadingListRules.maxComics),
        ],
      ),
    ],
  ),
  const WizardStep(ReadingListSteps.review, fields: []),
];

/// The wizard's values as the request body: the name trimmed (the backend
/// stores it trimmed), the comics as ids in the chosen order.
ReadingListDraft readingListDraftOf(FormValues values) => ReadingListDraft(
  name: _trimmedName(values.get<String>(ReadingListFields.name)),
  description: values.get<String>(ReadingListFields.description) ?? '',
  visibility:
      values.get<ReadingListVisibility>(ReadingListFields.visibility) ??
      ReadingListVisibility.private,
  comicIds: comicIdsOf(
    values.get<List<PickedComic>>(ReadingListFields.comics) ?? const [],
  ),
);
