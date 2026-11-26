import 'package:flutter/material.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// The app bar every page uses, so features do not hand-roll `AppBar`s.
///
/// **Leading slot.** [leading] is a plain widget slot, the same one `AppBar`
/// has. The design system does not know about flows: a feature that wants the
/// flow's back behaviour passes `leading: const McFlowBackButton()` (from
/// `mc_feature_flow`), so `mc_ds_navigation` never depends on
/// `mc_feature_flow`. When [leading] is null the bar falls back to what
/// `AppBar` shows itself (back, close or drawer button), so a page pushed
/// inside a flow needs nothing.
///
/// **Large title.** With [largeTitle] the title is drawn big under the toolbar
/// (iOS style) and the toolbar itself carries no title. The bar's height is
/// fixed, so the large title is single-line, ellipsised, and its text scale is
/// capped at [largeTitleMaxScale]; the full title stays available to screen
/// readers.
class McAppBar extends StatelessWidget implements PreferredSizeWidget {
  const McAppBar({
    required this.title,
    this.leading,
    this.actions = const [],
    this.largeTitle = false,
    this.titleKey,
    super.key,
  });

  /// The page title. A semantics header.
  final String title;

  /// Fills the leading slot; null means `AppBar`'s automatic leading.
  final Widget? leading;

  /// Trailing widgets. Each should be at least [mcMinTapTarget] square
  /// (`McIconButton` is).
  final List<Widget> actions;

  /// Draws the title large under the toolbar.
  final bool largeTitle;

  /// Key of the title text, for tests.
  final Key? titleKey;

  /// Height of the large-title band.
  static const double largeTitleExtent = 64;

  /// Cap of the text scale in the large title (the band has a fixed height).
  static const double largeTitleMaxScale = 1.5;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (largeTitle ? largeTitleExtent : 0));

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    return AppBar(
      leading: leading,
      actions: actions,
      centerTitle: true,
      scrolledUnderElevation: 0,
      titleTextStyle: McTypeScale.headline.copyWith(color: p.onSurface),
      // `AppBar` marks its title as a semantics header itself.
      title: largeTitle
          ? null
          : Text(
              title,
              key: titleKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      bottom: largeTitle
          ? PreferredSize(
              preferredSize: const Size.fromHeight(largeTitleExtent),
              child: _LargeTitle(title: title, titleKey: titleKey),
            )
          : null,
    );
  }
}

class _LargeTitle extends StatelessWidget {
  const _LargeTitle({required this.title, this.titleKey});

  final String title;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    return SizedBox(
      height: McAppBar.largeTitleExtent,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: McSpacing.lg,
            end: McSpacing.lg,
          ),
          child: Semantics(
            header: true,
            child: Text(
              title,
              key: titleKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: MediaQuery.textScalerOf(
                context,
              ).clamp(maxScaleFactor: McAppBar.largeTitleMaxScale),
              style: McTypeScale.display.copyWith(color: p.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
