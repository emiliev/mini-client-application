import 'package:library_reading_list_editor/src/domain/model/reading_list.dart';
import 'package:library_reading_list_editor/src/domain/model/save_failure.dart';
import 'package:library_reading_list_editor/src/domain/repository/reading_list_editor_repository.dart';
import 'package:mc_forms/mc_forms.dart';

/// The wizard's field names (one form over all three steps, `mc_forms`).
abstract final class ReadingListFields {
  static const String name = 'name';
  static const String description = 'description';
  static const String visibility = 'visibility';
  static const String comics = 'comics';

  /// The form field that holds [field]'s value.
  static String of(ListField field) => switch (field) {
    ListField.name => name,
    ListField.description => description,
    ListField.comics => comics,
  };
}

/// The backend's rules (`mc_fixtures_library` CONTRACT.md, "Validation"),
/// checked as the user types so a valid wizard is a valid request.
abstract final class ReadingListRules {
  /// A name has 1 to 60 characters after trimming.
  static const int nameMaxLength = 60;

  /// A description has at most 280 characters (not trimmed).
  static const int descriptionMaxLength = 280;

  /// A list has 1 to 100 comics. The backend accepts an empty list; the
  /// editor asks for at least one (P1-20).
  static const int maxComics = 100;
}

/// The step ids, in order. Step pages and the flow state count them 0 to 2.
abstract final class ReadingListSteps {
  static const String details = 'details';
  static const String comics = 'comics';
  static const String review = 'review';

  /// The step whose page shows [field].
  static int indexOf(ListField field) => switch (field) {
    ListField.name || ListField.description => 0,
    ListField.comics => 1,
  };
}

/// The values the backend refused (a `400` naming a field, T-0048-AC2), as
/// a feature rule: a field whose value is still the refused one fails with
/// the backend's verdict, so the step is invalid, Next and Finish are
/// blocked and the error shows under the field until the user changes it.
///
/// The backend and the kit can disagree. The backend counts runes and the
/// kit counts what the user sees (grapheme clusters), so a name of 31 flag
/// emoji passes here and fails there (F-0048 fact 3).
final class ServerVerdicts {
  final Map<ListField, ({String value, FieldError error})> _refused = {};

  /// Records that the backend refused [value] (the field's wire form) for
  /// [field], with [error] to show.
  void refuse(ListField field, String value, FieldError error) =>
      _refused[field] = (value: value, error: error);

  /// The rule for [field]: fails while the field's wire form ([wire] of the
  /// value) is the refused one.
  Validator<T> rule<T>(ListField field, String Function(T? value) wire) =>
      (value) {
        final refused = _refused[field];
        return refused != null && refused.value == wire(value)
            ? refused.error
            : null;
      };
}

/// A field's value as the backend sees it: what a verdict is about.
String wireValueOf(ListField field, Object? value) => switch (field) {
  ListField.name => _trimmedName(value as String?),
  ListField.description => (value as String?) ?? '',
  ListField.comics => _comicKey(value as List<PickedComic>?),
};

/// What the editor shows for a refused value of [rejection]'s field.
FieldError verdictFor(SaveRejected rejection) =>
    rejection.code == 'too_many_comics'
    ? const FieldError(
        ValidationCode.aboveMax,
        max: ReadingListRules.maxComics,
      )
    : const FieldError(ValidationCode.invalid);

String _trimmedName(String? value) => (value ?? '').trim();

String _comicKey(List<PickedComic>? comics) => [
  for (final comic in comics ?? const <PickedComic>[]) comic.id.value,
].join(',');

/// Applies [rule] to the trimmed text, as the backend trims a name.
Validator<String> _trimmed(Validator<String> rule) =>
    (value) => rule(value?.trim());

/// More than [max] items fails with [ValidationCode.aboveMax].
Validator<List<T>> _atMost<T>(int max) => (value) =>
    value != null && value.length > max
    ? FieldError(ValidationCode.aboveMax, max: max)
    : null;

/// The three steps over one form: details (name, description, visibility),
/// comics, and order and review (it reorders the comics field; no fields of
/// its own). [saved] pre-fills every step in edit mode.
List<WizardStep> readingListSteps({
  required ServerVerdicts verdicts,
  ReadingList? saved,
}) => [
  WizardStep(
    ReadingListSteps.details,
    fields: [
      FieldDef<String>(
        ReadingListFields.name,
        initial: saved?.name ?? '',
        validators: [
          Validators.required<String>(),
          _trimmed(Validators.maxLength(ReadingListRules.nameMaxLength)),
          verdicts.rule<String>(ListField.name, _trimmedName),
        ],
      ),
      FieldDef<String>(
        ReadingListFields.description,
        initial: saved?.description ?? '',
        validators: [
          Validators.maxLength(ReadingListRules.descriptionMaxLength),
          verdicts.rule<String>(ListField.description, (v) => v ?? ''),
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
          Validators.required<List<PickedComic>>(),
          _atMost<PickedComic>(ReadingListRules.maxComics),
          verdicts.rule<List<PickedComic>>(ListField.comics, _comicKey),
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
