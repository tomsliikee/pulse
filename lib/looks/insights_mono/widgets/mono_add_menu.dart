import 'package:material_ui/material_ui.dart';

import '../../../app/app_scope.dart';
import '../../../app/haptics.dart';
import '../../../data/models.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/mono_actions.dart';
import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import 'mono_category.dart';
import 'mono_floating_bar.dart';
import 'mono_motion.dart';

/// Opens what the + of the floating bar adds: a glass of water, a weight, a
/// meal or a supplement, fanned out above it. [bottom] is where the bar
/// stands from the lower edge of the screen.
Future<void> showMonoAddMenu(BuildContext context, {required double bottom}) {
  final t = MonoTokens.of(context);
  final l10n = AppLocalizations.of(context);
  final health = AppScope.of(context).health;
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: l10n.close,
      barrierColor: t.bg.withValues(alpha: 0.72),
      transitionDuration: monoStill(context)
          ? Duration.zero
          : const Duration(milliseconds: 380),
      reverseTransitionDuration: monoStill(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      pageBuilder: (menu, animation, _) {
        void pick(VoidCallback action) {
          Navigator.of(menu).pop();
          action();
        }

        final items = <(IconData, String, VoidCallback)>[
          (
            Icons.water_drop_rounded,
            l10n.metricWater,
            () => monoAddGlass(context, health),
          ),
          (
            Icons.monitor_weight_rounded,
            l10n.metricWeight,
            () => monoAddEntry(context, EntryKind.weight),
          ),
          (
            Icons.restaurant_rounded,
            l10n.entryMeal,
            () => monoAddEntry(context, EntryKind.meal),
          ),
          (
            MonoCategory.supplements.icon,
            l10n.supplement,
            () => monoAddSupplement(context),
          ),
        ];
        return _Menu(
          animation: animation,
          bottom: bottom,
          closeLabel: l10n.close,
          items: [
            for (final (icon, label, action) in items)
              (icon, label, () => pick(action)),
          ],
        );
      },
    ),
  );
}

/// Where the + stands from the right edge: the bar is centred.
double _right(BuildContext context) =>
    (MediaQuery.sizeOf(context).width - MonoFloatingBar.width) / 2;

class _Menu extends StatelessWidget {
  const _Menu({
    required this.animation,
    required this.bottom,
    required this.closeLabel,
    required this.items,
  });

  final Animation<double> animation;
  final double bottom;
  final String closeLabel;
  final List<(IconData, String, VoidCallback)> items;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final n = items.length;
    return Stack(
      children: [
        Positioned(
          right: _right(context),
          bottom: bottom + MonoFloatingBar.height + 18,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _Rise(
                  animation: animation,
                  // The one nearest the + comes first.
                  order: n - 1 - i,
                  child: _Item(
                    icon: items[i].$1,
                    label: items[i].$2,
                    onTap: items[i].$3,
                    tokens: t,
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          right: _right(context),
          bottom: bottom,
          child: Semantics(
            button: true,
            label: closeLabel,
            child: ExcludeSemantics(
              child: MonoPress(
                onTap: () {
                  Haptics.tap();
                  Navigator.of(context).pop();
                },
                squash: 0.08,
                child: MonoGlass(
                  child: SizedBox.square(
                    dimension: MonoFloatingBar.height,
                    child: AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) => Transform.rotate(
                        angle: animation.value * 0.785,
                        child: child,
                      ),
                      child: Icon(Icons.add_rounded, size: 30, color: t.ink),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Rise extends StatelessWidget {
  const _Rise({
    required this.animation,
    required this.order,
    required this.child,
  });

  final Animation<double> animation;
  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (order * 0.12).clamp(0.0, 0.6);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, 1, curve: Curves.easeOutBack),
      reverseCurve: Curves.easeIn,
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final p = curved.value;
        return Opacity(
          opacity: p.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - p) * 24),
            child: Transform.scale(
              scale: 0.86 + 0.14 * p,
              alignment: Alignment.centerRight,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tokens,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final MonoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: MonoPress(
          onTap: () {
            Haptics.tap();
            onTap();
          },
          squash: 0.04,
          child: Container(
            height: 56,
            padding: const EdgeInsets.only(left: 22, right: 6),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(28),
              boxShadow: t.barShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: MonoType.inter(16, 22, FontWeight.w600, t.ink),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.solid,
                  ),
                  child: Icon(icon, size: 22, color: t.onSolid),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
