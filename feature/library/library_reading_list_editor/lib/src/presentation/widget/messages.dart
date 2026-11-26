import 'package:library_reading_list_editor/src/l10n/reading_list_editor_l10n.dart';
import 'package:library_reading_list_editor/src/presentation/form/reading_list_form.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_forms/mc_forms.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

/// What the user reads for a failed request, from the shared error copy.
/// The raw failure text goes to monitoring only (`McBloc`).
String failureMessage(ApiFailure failure, McL10nCoreL10n core) =>
    switch (failure) {
      ApiTimeout() => core.errorTimeout,
      ApiOffline() => core.errorNetwork,
      ApiServer() => core.errorServer,
      _ => core.errorGeneric,
    };

/// The message under [field] for [error] (the kit reports codes only).
/// `invalid` is the backend's verdict on a value it refused.
String fieldErrorMessage(
  String field,
  FieldError error,
  ReadingListEditorL10n l10n,
) => switch (field) {
  ReadingListFields.comics => switch (error.code) {
    ValidationCode.required => l10n.readingListEditorComicsRequired,
    ValidationCode.aboveMax => l10n.readingListEditorComicsTooMany(
      error.max!.toInt(),
    ),
    _ => l10n.readingListEditorComicsRefused,
  },
  // The two text fields: required (name only), too long, or refused.
  _ => switch (error.code) {
    ValidationCode.required => l10n.readingListEditorNameRequired,
    ValidationCode.tooLong => l10n.readingListEditorTooLong(
      error.max!.toInt(),
    ),
    _ =>
      field == ReadingListFields.description
          ? l10n.readingListEditorDescriptionRefused
          : l10n.readingListEditorNameRefused,
  },
};
