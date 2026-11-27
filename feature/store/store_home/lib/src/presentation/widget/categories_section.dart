import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_media/mc_media.dart';
import 'package:store_home/src/domain/model/store.dart';
import 'package:store_home/src/domain/model/store_analytics.dart';
import 'package:store_home/src/presentation/bloc/categories_bloc.dart';
import 'package:store_home/src/presentation/widget/store_section.dart';

/// The categories: a grid whose column count follows the width (as
/// `McAdaptiveGrid`), with rows as tall as their text needs, so nothing
/// overflows at any text scale. A tap opens the category inside the flow.
class CategoriesSection extends StatelessWidget {
  const CategoriesSection({super.key});

  static const _section = StoreSection.categories;

  @override
  Widget build(BuildContext context) {
    final l10n = context.storeL10n;
    return StoreSectionFrame(
      section: _section,
      title: l10n.storeHomeCategories,
      child: BlocBuilder<CategoriesBloc, CategoriesState>(
        builder: (context, state) => state.when(
          loading: () => SectionSkeleton(
            section: _section,
            label: l10n.storeHomeSectionLoading(l10n.storeHomeCategories),
            height: 3 * 96 + 2 * McSpacing.md,
          ),
          empty: () => SectionEmpty(
            section: _section,
            message: l10n.storeHomeCategoriesEmpty,
          ),
          failure: (error, _) => SectionError(
            section: _section,
            title: l10n.storeHomeCategoriesError,
            error: error,
            onRetry: () => context.read<CategoriesBloc>().add(
              const CategoriesEvent.retry(),
            ),
          ),
          ready: (categories) => Padding(
            key: sectionPartKey(_section, 'content'),
            padding: McInsets.horizontal,
            child: _Grid(categories: categories),
          ),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.categories});

  final List<StoreCategory> categories;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = McAdaptiveGrid.columnsFor(constraints.maxWidth);
      return Column(
        children: [
          for (var row = 0; row * columns < categories.length; row++) ...[
            if (row > 0) const SizedBox(height: McSpacing.md),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) const SizedBox(width: McSpacing.md),
                    Expanded(
                      child: row * columns + col < categories.length
                          ? _CategoryTile(
                              category: categories[row * columns + col],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final StoreCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = context.storeL10n;
    final p = context.mcPalette;
    final text = Theme.of(context).textTheme;
    final count = l10n.storeHomeCategoryCount(category.count);
    void open() => context.read<CategoriesBloc>().add(
      CategoriesEvent.open(category),
    );
    return Semantics(
      key: ValueKey('store_home.category.${category.id.value}'),
      button: true,
      container: true,
      label: category.name,
      value: count,
      onTap: open,
      child: ExcludeSemantics(
        child: Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: McRadius.mdAll,
            side: BorderSide(color: p.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 2,
                  child: McImage(
                    image: category.image,
                    variant: ImageVariant.standard,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(McSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge,
                      ),
                      const SizedBox(height: McSpacing.xxs),
                      Text(
                        count,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
