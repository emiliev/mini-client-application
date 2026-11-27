import 'package:flutter/material.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:settings_appearance/src/presentation/widget/settings_spacing.dart';

/// Key of the explainer's body, for tests.
const aboutBodyKey = ValueKey<String>('settings_appearance_about.body');

/// "About themes": what each choice does. A page of the flow, above the
/// settings; Back returns to them.
class AboutThemesPage extends StatelessWidget {
  const AboutThemesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.settingsL10n;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: McAppBar(
        leading: const McFlowBackButton(),
        title: l10n.settingsAppearanceAbout,
      ),
      body: ListView(
        key: aboutBodyKey,
        padding: EdgeInsets.symmetric(
          horizontal: McSpacing.lg,
          vertical: context.groupGap,
        ),
        children: [
          for (final paragraph in [
            l10n.settingsAppearanceAboutSystem,
            l10n.settingsAppearanceAboutLightDark,
            l10n.settingsAppearanceAboutDensity,
            l10n.settingsAppearanceAboutReduceMotion,
            l10n.settingsAppearanceAboutSync,
          ]) ...[
            Text(paragraph, style: text.bodyLarge),
            SizedBox(height: context.groupGap),
          ],
        ],
      ),
    );
  }
}
