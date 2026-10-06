import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../theme/app_motion.dart';
import 'haptics.dart';

@immutable
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The app's navigation: an expressive floating toolbar whose selected
/// destination grows into a labelled pill.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.showLabel = true,
  });

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Narrow screens keep the selected pill icon-only.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return M3EHorizontalFloatingToolbar(
      expanded: true,
      decoration: M3EFloatingToolbarDecoration(
        colors: M3EFloatingToolbarColors(
          toolbarContainerColor: scheme.surfaceContainerHighest,
          toolbarContentColor: scheme.onSurfaceVariant,
          fabContainerColor: scheme.primaryContainer,
          fabContentColor: scheme.onPrimaryContainer,
        ),
        contentPadding: const EdgeInsets.all(8),
        expandedShadowElevation: 3,
      ),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < destinations.length; i++)
            _NavItem(
              destination: destinations[i],
              selected: i == selectedIndex,
              showLabel: showLabel,
              onTap: () {
                if (i != selectedIndex) Haptics.selection();
                onSelected(i);
              },
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        destination.label,
        maxLines: 1,
        softWrap: false,
        style: context.emphasizedTextTheme.labelLarge?.copyWith(
          color: scheme.onPrimary,
        ),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: destination.label,
      onTap: onTap,
      excludeSemantics: true,
      child: SingleMotionBuilder(
        value: selected ? 1 : 0,
        motion: AppMotion.spatialFast,
        builder: (context, t, label) {
          // The spring overshoots; colour and clip factors must stay valid.
          final clamped = t.clamp(0, 1).toDouble();
          return Material(
            color: Color.lerp(
              scheme.primary.withValues(alpha: 0),
              scheme.primary,
              clamped,
            ),
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: 48,
                constraints: const BoxConstraints(minWidth: 52),
                padding: EdgeInsets.symmetric(horizontal: 14 + 4 * clamped),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      size: 24,
                      color: Color.lerp(
                        scheme.onSurfaceVariant,
                        scheme.onPrimary,
                        clamped,
                      ),
                    ),
                    if (showLabel)
                      ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: t < 0 ? 0 : t,
                          child: Opacity(opacity: clamped, child: label),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        child: label,
      ),
    );
  }
}
