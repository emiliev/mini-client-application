import 'package:flutter/material.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// The app bar every page uses, so features do not hand-roll `AppBar`s.
///
/// **IMPORTANT: pass `leading: const McFlowBackButton()` on every flow page
/// that can be a flow's root.** This design-system package does not depend on
/// `mc_feature_flow` (a utility must not know the sibling that owns
/// navigation state), so `McAppBar` cannot default to the flow's back button.
/// Left null, [leading] falls back to what `AppBar` shows itself (back, close
/// or drawer button). That is right for a page pushed inside a flow, but a
/// flow has its own navigator, so on the flow's first page `AppBar` shows
/// nothing and the user cannot leave the flow on iOS. Features and bricks
/// therefore always pass `leading: const McFlowBackButton()` (from
/// `mc_feature_flow`), which is safe on every page.
///
/// **Large title.** With [largeTitle] the title is drawn big under the toolbar
/// (iOS style) and the toolbar itself carries no title. The band has a fixed
/// height, so the large title is single-line and ellipsised, and its text
/// scale is capped at [largeTitleMaxScale]. iOS truncates large titles too.
/// Screen readers still get the full title, and the title names the route.
/// Note that Flutter's `AppBar` itself caps the plain title's scale at 1.34,
/// so a plain title at "2x" renders at 1.34x.
///
/// **Bottom.** [bottom] (for example a [McTabBar]) goes under the title and
/// is part of [preferredSize].
class McAppBar extends StatelessWidget implements PreferredSizeWidget {
  const McAppBar({
    required this.title,
    this.leading,
    this.actions = const [],
    this.largeTitle = false,
    this.bottom,
    this.titleKey,
    super.key,
  });

  /// The page title. A semantics header.
  final String title;

  /// Fills the leading slot; null means `AppBar`'s automatic leading. See the
  /// class comment: flow pages pass `McFlowBackButton`.
  final Widget? leading;

  /// Trailing widgets. Each should be at least [mcMinTapTarget] square
  /// (`McIconButton` is).
  final List<Widget> actions;

  /// Draws the title large under the toolbar.
  final bool largeTitle;

  /// A widget under the title, such as a tab bar.
  final PreferredSizeWidget? bottom;

  /// Key of the title text, for tests.
  final Key? titleKey;

  /// Height of the large-title band.
  static const double largeTitleExtent = 64;

  /// Cap of the text scale in the large title (the band has a fixed height).
  static const double largeTitleMaxScale = 1.5;

  double get _bottomHeight =>
      (largeTitle ? largeTitleExtent : 0) + (bottom?.preferredSize.height ?? 0);

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + _bottomHeight);

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final extra = bottom;
    final PreferredSizeWidget? under;
    if (largeTitle) {
      under = PreferredSize(
        preferredSize: Size.fromHeight(_bottomHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LargeTitle(title: title, titleKey: titleKey),
            if (extra != null) extra,
          ],
        ),
      );
    } else {
      under = extra;
    }
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
      bottom: under,
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
          // The toolbar carries no title in this mode, so this one names the
          // route, as `AppBar`'s own title does.
          child: Semantics(
            header: true,
            namesRoute: true,
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
