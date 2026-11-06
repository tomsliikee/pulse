import 'package:material_ui/material_ui.dart';

import '../../../app/haptics.dart';
import '../data/mono_data.dart';
import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import 'mono_motion.dart';
import 'mono_page.dart';

/// One entry of a page the pencil can put in another order or hide.
class MonoEditItem {
  const MonoEditItem(this.id, this.label, this.icon, this.color);

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

/// The blocks of a page while the pencil is on: one short row each, to be
/// dragged by its handle or hidden with its minus; the hidden ones below,
/// with a plus. Order and hiding are kept under [page] in the settings.
class MonoEditList extends StatelessWidget {
  const MonoEditList({
    super.key,
    required this.c,
    required this.page,
    required this.items,
    required this.hidden,
  });

  final MonoCtx c;
  final String page;
  final List<MonoEditItem> items;
  final Set<String> hidden;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final l10n = c.l10n;
    final visible = [
      for (final item in items)
        if (!hidden.contains(item.id)) item,
    ];
    final off = [
      for (final item in items)
        if (hidden.contains(item.id)) item,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          padding: EdgeInsets.zero,
          proxyDecorator: (child, _, animation) => AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final p = Curves.easeOut.transform(animation.value);
              return Transform.scale(
                scale: 1 + 0.03 * p,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18 * p),
                        blurRadius: 24 * p,
                        offset: Offset(0, 10 * p),
                      ),
                    ],
                  ),
                  child: child,
                ),
              );
            },
            child: child,
          ),
          onReorderStart: (_) => Haptics.lift(),
          onReorderItem: (from, to) {
            final moved = [...visible];
            final item = moved.removeAt(from);
            moved.insert(to, item);
            Haptics.selection();
            // The hidden ones keep their place at the end.
            c.settings.setTileOrder(page, [
              for (final item in [...moved, ...off]) item.id,
            ]);
          },
          children: [
            for (var i = 0; i < visible.length; i++)
              Padding(
                key: ValueKey(visible[i].id),
                padding: const EdgeInsets.only(bottom: 12),
                child: _EditRow(
                  item: visible[i],
                  tokens: t,
                  action: Icons.remove_rounded,
                  actionLabel: l10n.monoHideCard,
                  onAction: () {
                    Haptics.tap();
                    c.settings.hideTile(page, visible[i].id);
                  },
                  handle: ReorderableDragStartListener(
                    index: i,
                    child: Semantics(
                      label: l10n.monoMoveCard,
                      child: SizedBox(
                        width: 48,
                        height: 56,
                        child: Icon(Icons.drag_handle_rounded, color: t.ink2),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (off.isNotEmpty) ...[
          const SizedBox(height: 28),
          MonoSection(l10n.monoHiddenCards),
          const SizedBox(height: 14),
          for (final item in off) ...[
            _EditRow(
              item: item,
              tokens: t,
              faded: true,
              action: Icons.add_rounded,
              actionLabel: l10n.monoShowCard,
              onAction: () {
                Haptics.tap();
                c.settings.showTile(page, item.id);
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.item,
    required this.tokens,
    required this.action,
    required this.actionLabel,
    required this.onAction,
    this.handle,
    this.faded = false,
  });

  final MonoEditItem item;
  final MonoTokens tokens;
  final IconData action;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget? handle;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final color = faded ? t.ink3 : item.color;
    return Container(
      height: 64,
      padding: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: '$actionLabel: ${item.label}',
            child: ExcludeSemantics(
              child: MonoPress(
                onTap: onAction,
                squash: 0.08,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: faded ? t.solid : t.heart,
                      ),
                      child: Icon(
                        action,
                        size: 18,
                        color: faded ? t.onSolid : t.bg,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(item.icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              style: MonoType.inter(
                16,
                22,
                FontWeight.w600,
                faded ? t.ink2 : t.ink,
              ),
            ),
          ),
          ?handle,
        ],
      ),
    );
  }
}
