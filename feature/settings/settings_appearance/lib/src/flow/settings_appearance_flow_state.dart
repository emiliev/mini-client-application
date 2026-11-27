import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_appearance_flow_state.freezed.dart';

/// What the flow shows, not which page is on top (plan 01 §4.1). Pure Dart,
/// so the bloc that updates it stays Flutter-free (R15). The preferences
/// themselves are app-wide (`mc_appearance`), never flow state.
@freezed
abstract class SettingsAppearanceFlowState with _$SettingsAppearanceFlowState {
  const factory SettingsAppearanceFlowState({
    /// The "About themes" explainer is open above the settings.
    @Default(false) bool aboutOpen,
  }) = _SettingsAppearanceFlowState;
}
