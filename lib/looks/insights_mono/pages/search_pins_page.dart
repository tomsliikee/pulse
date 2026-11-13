import 'package:material_ui/material_ui.dart';

import '../../../app/haptics.dart';
import '../../../data/settings_controller.dart';
import '../data/mono_data.dart';
import '../search/search_index.dart';
import '../search/search_sources.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_controls.dart';
import '../widgets/mono_motion.dart';
import '../widgets/mono_page.dart';

/// Which values the search shows before anything is typed, and in which
/// order: the pinned ones to be dragged or unpinned, then every value with
/// a switch.
class MonoSearchPinsPage extends StatelessWidget {
  const MonoSearchPinsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.settings, scope.health]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final l10n = c.l10n;
        final t = c.t;
        final values = valueItems(c);
        final pins = c.settings.searchPins;
        final pinned = pinnedOf(values, pins);
        final full = pins.length >= maxSearchPins;
        return MonoSubPage(
          category: MonoCategory.activity,
          icon: Icons.push_pin_rounded,
          categoryLabel: l10n.searchPinsTitle,
          backLabel: l10n.back,
          statement: l10n.searchPinsStatement,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonoSection(l10n.searchPinned),
                const SizedBox(height: 14),
                if (pinned.isEmpty)
                  Text(l10n.searchNoPins, style: MonoType.sub(t))
                else
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    padding: EdgeInsets.zero,
                    onReorderStart: (_) => Haptics.lift(),
                    onReorderItem: (from, to) {
                      final ids = [for (final p in pinned) p.id];
                      final id = ids.removeAt(from);
                      ids.insert(to, id);
                      Haptics.selection();
                      c.settings.setSearchPins(ids);
                    },
                    proxyDecorator: (child, _, animation) => AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) => Transform.scale(
                        scale: 1 + 0.03 * animation.value,
                        child: child,
                      ),
                      child: child,
                    ),
                    children: [
                      for (var i = 0; i < pinned.length; i++)
                        Padding(
                          key: ValueKey(pinned[i].id),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PinnedRow(c: c, item: pinned[i], index: i),
                        ),
                    ],
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonoSection(l10n.searchAllValues),
                const SizedBox(height: 6),
                Text(
                  l10n.searchPinsLimit(maxSearchPins),
                  style: MonoType.label(t),
                ),
                const SizedBox(height: 14),
                MonoSurface(
                  padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
                  child: Column(
                    children: [
                      for (final item in values)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: MonoType.inter(
                                      16,
                                      22,
                                      FontWeight.w500,
                                      t.ink,
                                    ),
                                  ),
                                  Text(
                                    [?item.valueText, item.group].join(' · '),
                                    style: MonoType.label(t),
                                  ),
                                ],
                              ),
                            ),
                            MonoSwitch(
                              label: item.title,
                              value: pins.contains(item.id),
                              onChanged: pins.contains(item.id) || !full
                                  ? (_) => c.settings.toggleSearchPin(item.id)
                                  : null,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PinnedRow extends StatelessWidget {
  const _PinnedRow({required this.c, required this.item, required this.index});

  final MonoCtx c;
  final SearchItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final category = searchValueCategory(item.id);
    return Container(
      height: 64,
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(category.icon, size: 20, color: category.color(t)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MonoType.inter(16, 22, FontWeight.w600, t.ink),
                ),
                if (item.valueText != null)
                  Text(item.valueText!, style: MonoType.label(t)),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: '${c.l10n.searchUnpin}: ${item.title}',
            child: ExcludeSemantics(
              child: MonoPress(
                onTap: () {
                  Haptics.tap();
                  c.settings.toggleSearchPin(item.id);
                },
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.fill,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    c.l10n.searchUnpin,
                    style: MonoType.inter(14, 18, FontWeight.w600, t.ink),
                  ),
                ),
              ),
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Semantics(
              label: c.l10n.monoMoveCard,
              child: SizedBox(
                width: 48,
                height: 56,
                child: Icon(Icons.drag_handle_rounded, color: t.ink2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
