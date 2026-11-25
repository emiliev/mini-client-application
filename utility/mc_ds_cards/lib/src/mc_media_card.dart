import 'package:flutter/material.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_media/mc_media.dart';

/// A tile with a picture, a title and an optional subtitle: what a character
/// grid is built from.
///
/// The title is one semantics button label (the picture is excluded, the
/// subtitle is its value); without [onTap] it is not a button. The card takes
/// the size of its cell: grid cells are well above the 44 pt tap target (a
/// test asserts it), so the card adds no minimum of its own. Use
/// [McMediaCard.skeleton] while the first page loads; a skeleton is excluded
/// from semantics, its list announces one "Loading".
///
/// The card fills the height it is given. In a grid, size cells with
/// [heightFor] so the text never overflows at large text scales.
class McMediaCard extends StatelessWidget {
  const McMediaCard({
    required String this.title,
    required ApiImage this.image,
    this.subtitle,
    this.onTap,
    super.key,
  }) : _skeleton = false;

  /// A grey block of the same shape, with no content and no tap.
  const McMediaCard.skeleton({super.key})
    : title = null,
      image = null,
      subtitle = null,
      onTap = null,
      _skeleton = true;

  /// Width over height of the picture: portrait.
  static const double imageAspectRatio = 0.8;

  static const _titleStyle = McTypeScale.label;
  static const _subtitleStyle = McTypeScale.caption;
  static const _textPadding = McSpacing.sm;

  final String? title;
  final ApiImage? image;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool _skeleton;

  /// The height of a card [width] wide, with room for [titleLines] title
  /// lines and, when [hasSubtitle], a one-line subtitle at [textScaler]. A
  /// grid of cards without subtitles passes `hasSubtitle: false`, so the cells
  /// do not reserve an empty line.
  static double heightFor({
    required double width,
    required TextScaler textScaler,
    bool hasSubtitle = true,
    int titleLines = 2,
  }) {
    double line(TextStyle style) =>
        textScaler.scale(style.fontSize!) * style.height!;
    final text =
        titleLines * line(_titleStyle) +
        (hasSubtitle ? McSpacing.xxs + line(_subtitleStyle) : 0) +
        2 * _textPadding;
    // Rounded up: a fractional line must not overflow.
    return (width / imageAspectRatio + text).ceilToDouble() + 1;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final theme = Theme.of(context).textTheme;
    final Widget body = _skeleton
        ? _Skeleton(color: p.surfaceVariant)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: imageAspectRatio,
                child: McImage(
                  image: image!,
                  variant: ImageVariant.portraitLarge,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(_textPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.labelLarge,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: McSpacing.xxs),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );

    final card = Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: McRadius.mdAll,
        side: BorderSide(color: p.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: _skeleton
          ? body
          : InkWell(
              onTap: onTap,
              child: body,
            ),
    );
    if (_skeleton) {
      return ExcludeSemantics(child: card);
    }
    return Semantics(
      button: onTap != null,
      enabled: onTap != null ? true : null,
      container: true,
      label: title,
      value: subtitle,
      onTap: onTap,
      child: ExcludeSemantics(child: card),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: McRadius.smAll),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: McMediaCard.imageAspectRatio,
          child: ColoredBox(color: color),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(McSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(0.8, 14),
                const SizedBox(height: McSpacing.sm),
                bar(0.5, 10),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
