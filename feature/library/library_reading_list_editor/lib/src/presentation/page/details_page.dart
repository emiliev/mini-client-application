import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_id.dart';
import 'package:library_reading_list_editor/src/l10n/reading_list_editor_l10n.dart';
import 'package:library_reading_list_editor/src/presentation/bloc/reading_list_editor_bloc.dart';
import 'package:library_reading_list_editor/src/presentation/form/reading_list_form.dart';
import 'package:library_reading_list_editor/src/presentation/widget/editor_step_bar.dart';
import 'package:library_reading_list_editor/src/presentation/widget/messages.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_forms/mc_ds_forms.dart';
import 'package:mc_ds_inputs/mc_ds_inputs.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_forms/mc_forms.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

/// Keys of step 1, for tests.
const detailsBodyKey = ValueKey<String>('reading_list_editor.details');
const visibilityKey = ValueKey<String>('reading_list_editor.visibility');
const closeEditorKey = ValueKey<String>('reading_list_editor.close');

/// Step 1, the flow's root page: name, description and visibility. Before
/// the wizard exists (signing in, loading the list) and when it cannot go on
/// (not found, a failed load, an ended session) this page shows that.
///
/// The editor bloc belongs to the flow, not to the page (every step page
/// shares it), so the page provides it with `BlocProvider.value`; the flow's
/// container closes it.
class ReadingListDetailsPage extends StatelessWidget {
  const ReadingListDetailsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    // The only DI lookup in UI code (R17).
    value: context.di<ReadingListEditorBloc>(),
    child: const _DetailsPageContent(),
  );
}

/// Maps each editor state to UI.
class _DetailsPageContent extends StatelessWidget {
  const _DetailsPageContent();

  @override
  Widget build(BuildContext context) {
    final l10n = ReadingListEditorL10n.of(context);
    final core = McL10nCoreL10n.of(context);
    return BlocBuilder<ReadingListEditorBloc, ReadingListEditorState>(
      builder: (context, state) {
        final bloc = context.read<ReadingListEditorBloc>();
        return Scaffold(
          appBar: McAppBar(
            leading: const McFlowBackButton(),
            title: state.maybeWhen(
              editing: (_, existing) => existing
                  ? l10n.readingListEditorEditTitle
                  : l10n.readingListEditorNewTitle,
              orElse: () => l10n.readingListEditorTitle,
            ),
          ),
          body: state.when(
            loading: () =>
                McLoading(semanticLabel: l10n.readingListEditorLoading),
            signingIn: () => McEmptyView(
              title: l10n.readingListEditorSignInTitle,
              message: l10n.readingListEditorSignInMessage,
            ),
            notFound: () => McEmptyView(
              title: l10n.readingListEditorNotFoundTitle,
              message: l10n.readingListEditorNotFoundMessage,
            ),
            loadFailed: (error, _) => McErrorView(
              title: l10n.readingListEditorLoadErrorTitle,
              message: failureMessage(error, core),
              retryLabel: core.commonRetry,
              onRetry: () => bloc.add(const ReadingListEditorEvent.retry()),
            ),
            sessionEnded: () => _SessionEnded(
              onClose: () => bloc.add(const ReadingListEditorEvent.close()),
            ),
            editing: (wizard, _) => _DetailsForm(wizard: wizard),
          ),
          bottomNavigationBar: state.maybeWhen(
            editing: (wizard, existing) =>
                EditorStepBar(step: 0, wizard: wizard, existing: existing),
            orElse: () => null,
          ),
        );
      },
    );
  }
}

class _DetailsForm extends StatelessWidget {
  const _DetailsForm({required this.wizard});

  final WizardState<ReadingListId> wizard;

  @override
  Widget build(BuildContext context) {
    final l10n = ReadingListEditorL10n.of(context);
    final bloc = context.read<ReadingListEditorBloc>();
    final form = wizard.form;
    final visibility = form.fieldOf<ReadingListVisibility>(
      ReadingListFields.visibility,
    );
    return ListView(
      key: detailsBodyKey,
      padding: McInsets.screen,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        McFieldGroup(
          title: l10n.readingListEditorDetailsTitle,
          description: l10n.readingListEditorDetailsHint,
          enabled: !wizard.isCompleting,
          children: [
            McFormTextField(
              field: form.fieldOf<String>(ReadingListFields.name),
              label: l10n.readingListEditorNameLabel,
              onChanged: (v) => bloc.add(ReadingListEditorEvent.nameChanged(v)),
              onTouched: () => bloc.add(
                const ReadingListEditorEvent.touched(ReadingListFields.name),
              ),
              errorMessage: (e) =>
                  fieldErrorMessage(ReadingListFields.name, e, l10n),
              textInputAction: TextInputAction.next,
            ),
            McFormTextField(
              field: form.fieldOf<String>(ReadingListFields.description),
              label: l10n.readingListEditorDescriptionLabel,
              onChanged: (v) =>
                  bloc.add(ReadingListEditorEvent.descriptionChanged(v)),
              onTouched: () => bloc.add(
                const ReadingListEditorEvent.touched(
                  ReadingListFields.description,
                ),
              ),
              errorMessage: (e) =>
                  fieldErrorMessage(ReadingListFields.description, e, l10n),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.readingListEditorVisibilityLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const McGap.xs(),
                McSegmented(
                  key: visibilityKey,
                  segments: [
                    McSegment(label: l10n.readingListEditorPrivate),
                    McSegment(label: l10n.readingListEditorPublic),
                  ],
                  selectedIndex:
                      (visibility.value ?? ReadingListVisibility.private).index,
                  onChanged: wizard.isCompleting
                      ? null
                      : (i) => bloc.add(
                          ReadingListEditorEvent.visibilityChanged(
                            ReadingListVisibility.values[i],
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// An error under a field the kit has no bound widget for (the visibility,
/// the picked comics), announced when it appears, as `McTextField` does.
class FieldErrorText extends StatelessWidget {
  const FieldErrorText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    container: true,
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.mcPalette.error),
    ),
  );
}

class _SessionEnded extends StatelessWidget {
  const _SessionEnded({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = ReadingListEditorL10n.of(context);
    final core = McL10nCoreL10n.of(context);
    return Column(
      children: [
        Expanded(
          child: McEmptyView(
            title: l10n.readingListEditorSessionEndedTitle,
            message: l10n.readingListEditorSessionEndedMessage,
          ),
        ),
        Padding(
          padding: McInsets.screen,
          child: McButton(
            key: closeEditorKey,
            label: core.commonClose,
            onPressed: onClose,
            expand: true,
          ),
        ),
      ],
    );
  }
}
