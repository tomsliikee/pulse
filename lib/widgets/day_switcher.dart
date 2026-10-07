import 'dart:async';

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../app/formatters.dart';
import '../app/haptics.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_motion.dart';
import 'floating_surface.dart';
import 'floating_tab_bar.dart';

/// The bar at the bottom of a page about one day: today, yesterday, and a
/// third tab that lets a column of pills rise above it, one for each of the
/// days before and one that leads to all of them. While an older day is
/// shown, the third tab carries its date.
class DaySwitcher extends StatefulWidget {
  const DaySwitcher({
    super.key,
    required this.today,
    required this.selected,
    required this.earlier,
    required this.allLabel,
    required this.onSelected,
    required this.onAll,
    this.glass = false,
  });

  final DateTime today;
  final DateTime selected;

  /// The days before yesterday that the pills offer, newest first.
  final List<DateTime> earlier;

  /// The last pill, which leads to every day.
  final String allLabel;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onAll;
  final bool glass;

  /// How many days the pills list.
  static const int menuDays = 5;

  @override
  State<DaySwitcher> createState() => _DaySwitcherState();
}

class _DaySwitcherState extends State<DaySwitcher> {
  static const double _gap = 8;

  /// How much later each pill starts than the one below it, as a share of
  /// the whole movement.
  static const double _stagger = 0.16;

  /// Long enough for the pills to fall back before they are taken away.
  static const Duration _closing = Duration(milliseconds: 320);

  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  bool _open = false;
  Timer? _hide;

  DateTime get _yesterday =>
      DateTime(widget.today.year, widget.today.month, widget.today.day - 1);

  void _toggle() {
    Haptics.selection();
    _open ? _close() : _show();
  }

  void _show() {
    _hide?.cancel();
    _portal.show();
    setState(() => _open = true);
  }

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
    _hide?.cancel();
    _hide = Timer(_closing, () {
      if (mounted && !_open) _portal.hide();
    });
  }

  void _pick(int index) {
    if (index == 2) return _toggle();
    // The bar stays live under the pills: one tap closes them and switches.
    _close();
    widget.onSelected(index == 0 ? widget.today : _yesterday);
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    final l10n = AppLocalizations.of(context);
    final selected = widget.selected;
    final index = selected == widget.today
        ? 0
        : selected == _yesterday
        ? 1
        : 2;
    return PopScope(
      // Back takes the pills away before it leaves the page.
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: TapRegion(
        groupId: _link,
        onTapOutside: (_) => _close(),
        child: CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _portal,
            overlayChildBuilder: (context) => Positioned(
              left: 0,
              top: 0,
              child: CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: Alignment.topRight,
                followerAnchor: Alignment.bottomRight,
                offset: const Offset(0, -_gap),
                child: TapRegion(groupId: _link, child: _pills(context)),
              ),
            ),
            child: FloatingTabBar(
              labels: [
                l10n.navToday,
                l10n.periodYesterday,
                index == 2 ? formats.shortDate(selected) : l10n.dayTabMore,
              ],
              icons: {
                2: SingleMotionBuilder(
                  value: _open ? 0.5 : 0,
                  motion: AppMotion.spatialFast,
                  builder: (context, turns, child) =>
                      Transform.rotate(angle: turns * 6.283185, child: child),
                  child: const Icon(Icons.expand_less_rounded),
                ),
              },
              selectedIndex: index,
              glass: widget.glass,
              onSelected: _pick,
              // The pills open again from the tab that shows an older day.
              onReselected: (tab) {
                if (tab == 2) _toggle();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _pills(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final style = context.emphasizedTextTheme.labelLarge;
    // From the top down; the last one sits right above the bar.
    final pills = <Widget>[
      for (final day in widget.earlier)
        _Pill(
          glass: widget.glass,
          onTap: () {
            Haptics.selection();
            _close();
            widget.onSelected(day);
          },
          children: [
            Text(
              formats.shortDate(day),
              style: style?.copyWith(color: scheme.onSurface),
            ),
            if (day == widget.selected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_rounded, size: 18, color: scheme.primary),
            ],
          ],
        ),
      _Pill(
        glass: widget.glass,
        color: scheme.primary,
        onTap: () {
          _close();
          widget.onAll();
        },
        children: [
          Text(
            widget.allLabel,
            style: style?.copyWith(color: scheme.onPrimary),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 18, color: scheme.onPrimary),
        ],
      ),
    ];
    final still = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      ignoring: !_open,
      child: SingleMotionBuilder(
        from: still ? 1 : 0,
        value: _open ? 1 : 0,
        motion: AppMotion.spatial,
        builder: (context, t, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (index, pill) in pills.indexed) ...[
              if (index > 0) const SizedBox(height: _gap),
              _rising(pill, t, pills.length - 1 - index, pills.length),
            ],
          ],
        ),
      ),
    );
  }

  /// [pill] at [t] of the whole movement, as the [place]-th from the bar:
  /// each one starts a little after the one below it, out of the tab.
  Widget _rising(Widget pill, double t, int place, int count) {
    final span = 1 + _stagger * (count - 1);
    final own = (t * span - _stagger * place).clamp(0.0, 1.0);
    return Opacity(
      opacity: own,
      child: Transform.translate(
        offset: Offset(0, 20 * (1 - own)),
        child: Transform.scale(
          scale: 0.6 + 0.4 * own,
          alignment: Alignment.bottomRight,
          child: pill,
        ),
      ),
    );
  }
}

/// One entry above the bar, a pill of its own.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.glass,
    required this.onTap,
    required this.children,
    this.color,
  });

  final bool glass;
  final VoidCallback onTap;
  final List<Widget> children;

  /// The fill; the bar's when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FloatingSurface(
      glass: glass,
      color: color,
      glassTint: color?.withValues(alpha: 0.72),
      child: InkWell(
        onTap: onTap,
        // As tall as the pill, so the label is centred in the glass too.
        child: Container(
          height: FloatingSurface.height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}
