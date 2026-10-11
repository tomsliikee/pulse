import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/food_archive.dart';
import '../../theme/app_theme.dart';
import '../../widgets/entrance.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/shape_badge.dart';

/// What the food sheet was left with, where that was not a [Food].
enum FoodChoice { more, create }

/// "520 kcal · 32 g Eiweiss · 12×": what a food is, at a glance.
String foodLine(Formats formats, Food food) {
  final protein = food.protein;
  return [
    '${formats.integer(food.kcal.round())} kcal',
    if (protein != null && protein > 0)
      '${formats.integer(protein.round())} g ${formats.l10n.metricProtein}',
    if (food.eaten.length > 1) '${food.eaten.length}×',
  ].join(' · ');
}

/// One food logged before; a tap takes it.
class FoodRow extends StatelessWidget {
  const FoodRow({super.key, required this.food, required this.onTap});

  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = scheme.tone(Tone.tertiary);
    return InkWell(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            ShapeBadge(
              shape: Shapes.c7SidedCookie,
              icon: Icons.restaurant_rounded,
              size: 44,
              color: tone.container,
              iconColor: tone.onContainer,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    foodLine(Formats.of(context), food),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.add_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Where a new meal starts: the foods eaten most often lately, the way to
/// all of them, and the empty form. Pops with the [Food] taken or a
/// [FoodChoice].
class FoodSheet extends StatelessWidget {
  const FoodSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = Formats.of(context).l10n;
    final health = AppScope.of(context).health;
    final navigator = Navigator.of(context);
    final shown = health.foods.where((food) => !food.hidden).length;
    final top = topFoods(health.foods, DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.addMeal,
              style: context.emphasizedTextTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.foodsOften,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final (index, food) in top.indexed)
              Entrance(
                order: index,
                child: ListSegment(
                  first: index == 0,
                  last: index == top.length - 1,
                  child: FoodRow(food: food, onTap: () => navigator.pop(food)),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (shown > top.length) ...[
                  Expanded(
                    child: M3EFilledButton.tonal(
                      size: M3EButtonSize.md,
                      onPressed: () {
                        Haptics.tap();
                        navigator.pop(FoodChoice.more);
                      },
                      child: Text(l10n.foodsMore),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: M3EFilledButton(
                    size: M3EButtonSize.md,
                    onPressed: () {
                      Haptics.tap();
                      navigator.pop(FoodChoice.create);
                    },
                    child: Text(l10n.foodNew),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
