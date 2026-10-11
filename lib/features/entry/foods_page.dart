import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/food_archive.dart';
import '../../data/health_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_shapes.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/sub_page.dart';
import 'food_sheet.dart';

extension on FoodSort {
  String label(AppLocalizations l10n) => switch (this) {
    FoodSort.recent => l10n.foodSortRecent,
    FoodSort.frequent => l10n.foodSortFrequent,
    FoodSort.name => l10n.foodSortName,
    FoodSort.kcal => l10n.foodSortKcal,
  };
}

extension on FoodDaytime {
  String label(AppLocalizations l10n) => switch (this) {
    FoodDaytime.morning => l10n.foodMorning,
    FoodDaytime.midday => l10n.foodMidday,
    FoodDaytime.evening => l10n.foodEvening,
  };
}

extension on FoodEnergy {
  String label(AppLocalizations l10n) => switch (this) {
    FoodEnergy.low => l10n.foodLow,
    FoodEnergy.middle => l10n.foodMiddle,
    FoodEnergy.high => l10n.foodHigh,
  };
}

/// Every food logged before, to search, sort and filter. A tap pops with
/// the [Food]; a swipe takes it out of the suggestions until it is eaten
/// again.
class FoodsPage extends StatefulWidget {
  const FoodsPage({super.key});

  @override
  State<FoodsPage> createState() => _FoodsPageState();
}

class _FoodsPageState extends State<FoodsPage> {
  final TextEditingController _query = TextEditingController();
  FoodSort _sort = FoodSort.recent;
  FoodDaytime? _daytime;
  FoodEnergy? _energy;
  bool _proteinRich = false;
  bool _ownOnly = false;

  /// Swiped away, and not yet gone from the archive.
  final Set<String> _swiped = {};

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _set(VoidCallback change) {
    Haptics.selection();
    setState(change);
  }

  Future<void> _hide(HealthController health, Food food) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = Formats.of(context).l10n;
    setState(() => _swiped.add(food.key));
    await health.hideFood(food);
    if (mounted) setState(() => _swiped.remove(food.key));
    Haptics.confirm();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.foodHidden(food.name)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => health.hideFood(food, hidden: false),
          ),
        ),
      );
  }

  Widget _chips(List<Widget> chips) => SizedBox(
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: chips.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) => Center(child: chips[index]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([health, scope.settings, _query]),
      builder: (context, _) {
        final l10n = Formats.of(context).l10n;
        final foods = findFoods(
          health.foods,
          query: _query.text,
          sort: _sort,
          daytime: _daytime,
          energy: _energy,
          proteinRich: _proteinRich,
          ownOnly: _ownOnly,
        ).where((food) => !_swiped.contains(food.key)).toList();
        return SubPage(
          title: l10n.foodsTitle,
          glass: scope.settings.liquidGlass,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.foodsSearch,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _query.clear,
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.large),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _chips([
                    for (final sort in FoodSort.values)
                      ChoiceChip(
                        label: Text(sort.label(l10n)),
                        selected: _sort == sort,
                        onSelected: (_) => _set(() => _sort = sort),
                      ),
                  ]),
                  _chips([
                    for (final daytime in FoodDaytime.values)
                      FilterChip(
                        label: Text(daytime.label(l10n)),
                        selected: _daytime == daytime,
                        onSelected: (on) =>
                            _set(() => _daytime = on ? daytime : null),
                      ),
                    FilterChip(
                      label: Text(l10n.foodProteinRich),
                      selected: _proteinRich,
                      onSelected: (on) => _set(() => _proteinRich = on),
                    ),
                    for (final energy in FoodEnergy.values)
                      FilterChip(
                        label: Text(energy.label(l10n)),
                        selected: _energy == energy,
                        onSelected: (on) =>
                            _set(() => _energy = on ? energy : null),
                      ),
                    FilterChip(
                      label: Text(l10n.foodOwnOnly),
                      selected: _ownOnly,
                      onSelected: (on) => _set(() => _ownOnly = on),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (foods.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        l10n.foodsNone,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SliverList.builder(
              itemCount: foods.length,
              itemBuilder: (context, index) {
                final food = foods[index];
                return Dismissible(
                  key: ValueKey(food.key),
                  onDismissed: (_) => _hide(health, food),
                  child: ListSegment(
                    first: index == 0,
                    last: index == foods.length - 1,
                    child: FoodRow(
                      food: food,
                      onTap: () => Navigator.of(context).pop(food),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
