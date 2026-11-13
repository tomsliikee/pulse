import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/haptics.dart';
import '../../../data/metric_catalog.dart';
import '../../../features/profile/profile_page.dart';
import '../../../features/supplements/supplement_detail_page.dart';
import '../data/mono_data.dart';
import '../pages/category_page.dart';
import '../pages/day_page.dart';
import '../pages/metric_page.dart';
import '../pages/search_pins_page.dart';
import '../pages/sleep_page.dart';
import '../pages/training/exercise_page.dart';
import '../pages/training/session_page.dart';
import '../pages/training/templates_page.dart';
import '../pages/workout_page.dart';
import '../shell/mono_dock.dart';
import '../shell/mono_dock_controller.dart';
import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_add_menu.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_floating_bar.dart';
import '../widgets/mono_motion.dart';
import 'search_index.dart';
import 'search_sources.dart';

/// The search while it is open: a dim layer over the page and the tall
/// glass panel above the search bar. Popping it closes the search.
class MonoSearchRoute extends PopupRoute<void> with MonoDockKeeps {
  MonoSearchRoute({
    required this.query,
    required this.onEdit,
    required this.openness,
    required this.home,
    this.onDrag,
    this.onRelease,
  });

  /// How open the search bar of the dock is, 0 in its place to 1 open. The
  /// panel takes its shape from it, so the two move as one.
  final Animation<double> openness;

  /// Where the search bar stands in the dock while closed, on the screen:
  /// the place the panel shrinks into.
  final Rect Function() home;

  /// How far the panel is pulled down, 0 to 1, for the search bar to follow
  /// it back towards its place in the dock.
  final ValueChanged<double>? onDrag;

  /// The finger let go: whether the search closes, and how fast the bar
  /// should go on, in shares of the way per second.
  final void Function(bool closing, double velocity)? onRelease;

  /// The text of the search bar.
  final ValueNotifier<String> query;

  /// Puts the keyboard away, for a drag in the panel.
  final VoidCallback onEdit;

  // The search field of the dock keeps the focus.
  @override
  bool get requestFocus => false;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.16);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'close';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 550);

  @override
  // Long enough for the panel to reach the bar before the route goes.
  Duration get reverseTransitionDuration => const Duration(milliseconds: 360);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _Panel(
    query: query,
    animation: animation,
    openness: openness,
    home: home,
    onDrag: onEdit,
    onPull: onDrag,
    onRelease: onRelease,
  );
}

class _Panel extends StatefulWidget {
  const _Panel({
    required this.query,
    required this.animation,
    required this.openness,
    required this.home,
    required this.onDrag,
    this.onPull,
    this.onRelease,
  });

  final ValueNotifier<String> query;
  final Animation<double> animation;
  final Animation<double> openness;
  final Rect Function() home;
  final VoidCallback onDrag;
  final ValueChanged<double>? onPull;
  final void Function(bool closing, double velocity)? onRelease;

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> with SingleTickerProviderStateMixin {
  List<SearchItem>? _items;
  List<SearchItem>? _values;

  /// How far the panel is pulled down; springs back when let go too early.
  late final AnimationController _pull = AnimationController.unbounded(
    vsync: this,
  )..addListener(_pulled);
  double get _drag => _pull.value;

  /// The pull at which the panel is back in the bar: as far as its top
  /// edge goes, so the edge stays under the finger.
  double _reach = 320;

  void _pulled() {
    widget.onPull?.call((_drag / _reach).clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _pull.dispose();
    super.dispose();
  }

  // The pins need the values only; the whole index is made with the first
  // letter typed, not in the frame the panel opens in.
  List<SearchItem> _index(MonoCtx c) => _items ??= buildSearchIndex(c);
  List<SearchItem> _pinnable(MonoCtx c) => _values ??= valueItems(c);

  bool _closing = false;

  /// The open shape when a pull began; the keyboard going down must not
  /// stretch the panel while it shrinks into the bar.
  Rect? _pullFrom;
  Rect _openNow = Rect.zero;

  void _dragBy(double dy) {
    if (_closing) return;
    _pullFrom ??= _openNow;
    widget.onDrag();
    _pull.value = (_drag + dy).clamp(0.0, 600.0);
  }

  void _dragEnd(double velocity) {
    if (_closing || _drag == 0 && velocity <= 0) return;
    if (_drag > 110 || velocity > 700) {
      _closing = true;
      Haptics.tap();
      widget.onRelease?.call(true, velocity.clamp(0, 4000) / _reach);
      Navigator.of(context).pop();
    } else {
      widget.onRelease?.call(false, 0);
      if (monoStill(context)) {
        _pull.value = 0;
      } else {
        _pull.animateWith(SpringSimulation(monoSettle, _drag, 0, velocity));
      }
      _pullFrom = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MonoCtx.of(context);
    final t = c.t;
    final media = MediaQuery.of(context);
    final size = media.size;
    _openNow = Rect.fromLTRB(
      12,
      media.padding.top + 52,
      size.width - 12,
      size.height - MonoDockSize.openBarTop(context) - 10,
    );
    final open = _pullFrom ?? _openNow;
    final content = ValueListenableBuilder<String>(
      valueListenable: widget.query,
      builder: (context, q, _) => _Content(
        c: c,
        tokens: t,
        query: q,
        items: q.trim().isEmpty ? _pinnable(c) : _index(c),
        onDrag: _dragBy,
        onDragEnd: _dragEnd,
      ),
    );
    return AnimatedBuilder(
      animation: widget.openness,
      child: content,
      builder: (context, child) {
        final home = widget.home();
        _reach = math.max(200, home.top - open.top);
        // One shape: open it is the panel, closed it is the search bar of
        // the dock, which is drawn over it and takes over as they meet.
        final o = widget.openness.value.clamp(0.0, 1.0);
        final rect = Rect.lerp(home, open, o)!;
        final radius = lerpDouble(home.height / 2, 30, o)!;
        // The content goes first, the glass only at the end, so nothing
        // lies under the bar once it is home.
        final shown = Curves.easeOut.transform(
          ((o - 0.55) / 0.45).clamp(0.0, 1.0),
        );
        final glass = (o / 0.18).clamp(0.0, 1.0);
        return Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: MonoGlass(
                radius: radius,
                shadow: false,
                opacity: glass,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minWidth: open.width,
                    maxWidth: open.width,
                    minHeight: open.height,
                    maxHeight: open.height,
                    child: Opacity(
                      opacity: shown,
                      child: IgnorePointer(
                        ignoring: _closing || o < 0.5,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.c,
    required this.tokens,
    required this.query,
    required this.items,
    required this.onDrag,
    required this.onDragEnd,
  });

  final MonoCtx c;
  final MonoTokens tokens;
  final String query;
  final List<SearchItem> items;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onDragEnd;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final l10n = c.l10n;
    final q = query.trim();
    final pinned = q.isEmpty;
    final hits = pinned
        ? pinnedOf(items, c.settings.searchPins)
        : querySearch(items, q);
    final title = pinned ? l10n.searchPinned : l10n.searchResults(hits.length);
    final rows = <Widget>[];
    SearchKind? group;
    for (final (i, item) in hits.indexed) {
      if (!pinned && item.kind != group) {
        group = item.kind;
        rows.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, rows.isEmpty ? 4 : 18, 4, 6),
            child: Text(
              searchGroupLabel(c, item.kind),
              style: MonoType.label(t),
            ),
          ),
        );
      }
      rows.add(
        _RiseIn(
          key: ValueKey(
            '${pinned ? 'pin' : 'hit'}/${item.kind.name}/${item.id}',
          ),
          order: i,
          child: _ResultRow(c: c, item: item),
        ),
      );
    }
    return Semantics(
      container: true,
      label: pinned ? title : l10n.searchResultsLabel(hits.length),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
            onVerticalDragEnd: (d) => onDragEnd(d.primaryVelocity ?? 0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: t.ink3.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      title,
                      style: MonoType.inter(22, 28, FontWeight.w600, t.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: NotificationListener<OverscrollNotification>(
              onNotification: (n) {
                if (n.overscroll < 0 && n.dragDetails != null) {
                  onDrag(-n.overscroll);
                }
                return false;
              },
              child: NotificationListener<ScrollEndNotification>(
                onNotification: (n) {
                  onDragEnd(0);
                  return false;
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    ...rows,
                    if (!pinned && hits.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 24, 8, 0),
                        child: Text(l10n.searchNothing, style: MonoType.sub(t)),
                      ),
                    if (pinned && hits.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                        child: Text(l10n.searchNoPins, style: MonoType.sub(t)),
                      ),
                    if (pinned) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _EditPins(c: c),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          _Actions(c: c),
        ],
      ),
    );
  }
}

/// What the + of the dock used to hold, under the results: water, weight,
/// meal, training and supplement.
class _Actions extends StatelessWidget {
  const _Actions({required this.c});

  final MonoCtx c;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final actions = monoAddActions(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.line, width: 0.8)),
      ),
      child: Row(
        children: [
          for (final a in actions)
            Expanded(
              child: Semantics(
                button: true,
                label: a.label,
                child: ExcludeSemantics(
                  child: MonoPress(
                    squash: 0.08,
                    onTap: () {
                      Haptics.tap();
                      final nav = Navigator.of(context);
                      nav.pop();
                      FocusManager.instance.primaryFocus?.unfocus();
                      a.run(nav.context);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: t.fill,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(a.icon, size: 22, color: t.ink),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          a.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MonoType.inter(
                            12,
                            16,
                            FontWeight.w500,
                            t.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditPins extends StatelessWidget {
  const _EditPins({required this.c});

  final MonoCtx c;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    return Semantics(
      button: true,
      child: MonoPress(
        onTap: () {
          Haptics.tap();
          final nav = Navigator.of(context);
          nav.pop();
          FocusManager.instance.primaryFocus?.unfocus();
          nav.push(
            MaterialPageRoute<void>(builder: (_) => const MonoSearchPinsPage()),
          );
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: t.fill,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.push_pin_rounded, size: 18, color: t.ink),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  c.l10n.searchEditPins,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MonoType.inter(15, 20, FontWeight.w600, t.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.c, required this.item});

  final MonoCtx c;
  final SearchItem item;

  IconData get _icon => switch (item.kind) {
    SearchKind.value => searchValueCategory(item.id).icon,
    SearchKind.exercise => Icons.fitness_center_rounded,
    SearchKind.workout => Icons.bolt_rounded,
    SearchKind.supplement => MonoCategory.supplements.icon,
    SearchKind.day => Icons.calendar_today_rounded,
    SearchKind.setting => Icons.tune_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final color = item.kind == SearchKind.value
        ? searchValueCategory(item.id).color(t)
        : t.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Semantics(
        button: true,
        label: [item.title, ?item.valueText, ?item.subtitle].join(', '),
        child: ExcludeSemantics(
          child: MonoPress(
            squash: 0.015,
            onTap: () => openSearchItem(context, item),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: t.fill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_icon, size: 19, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MonoType.inter(16, 21, FontWeight.w500, t.ink),
                        ),
                        if (item.subtitle != null && item.subtitle!.isNotEmpty)
                          Text(
                            item.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MonoType.label(t),
                          ),
                      ],
                    ),
                  ),
                  if (item.valueText != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      item.valueText!,
                      style: MonoType.inter(15, 20, FontWeight.w600, t.ink),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row that rises in when the results change, one after the other.
class _RiseIn extends StatelessWidget {
  const _RiseIn({super.key, required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (monoStill(context)) return child;
    final delay = (order.clamp(0, 10)) * 0.06;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (delay * 1000).round()),
      curve: Interval(delay / (0.26 + delay), 1, curve: Curves.easeOutCubic),
      builder: (context, p, child) => Transform.translate(
        offset: Offset(0, (1 - p) * 12),
        child: Opacity(opacity: p, child: child),
      ),
      child: child,
    );
  }
}

/// Opens the page of [item] and closes the search.
void openSearchItem(BuildContext context, SearchItem item) {
  Haptics.tap();
  final nav = Navigator.of(context);
  final c = MonoCtx.of(context);
  final page = _pageOf(c, item);
  nav.pop();
  FocusManager.instance.primaryFocus?.unfocus();
  if (page == null) return;
  nav.push(MaterialPageRoute<void>(builder: (_) => page));
}

Widget? _pageOf(MonoCtx c, SearchItem item) {
  final back = c.l10n.monoSearch;
  switch (item.kind) {
    case SearchKind.value:
      if (item.id == recoveryId) {
        return MonoCategoryPage(
          category: MonoCategory.recovery,
          backLabel: back,
        );
      }
      for (final m in Metric.values) {
        if (m.name != item.id) continue;
        if (m == Metric.sleep) return MonoSleepPage(backLabel: back);
        return MonoMetricPage(metric: m);
      }
      return null;
    case SearchKind.exercise:
      return MonoExercisePage(exerciseId: item.id);
    case SearchKind.workout:
      if (item.id.startsWith('session:')) {
        return MonoSessionPage(sessionId: item.id.substring(8));
      }
      for (final w in c.health.workouts) {
        if (w.key == item.id) return MonoWorkoutPage(workout: w);
      }
      return null;
    case SearchKind.supplement:
      return SupplementDetailPage(supplementKey: item.id);
    case SearchKind.day:
      final day = DateTime.tryParse(item.id);
      return day == null ? null : MonoDayPage(date: day, backLabel: back);
    case SearchKind.setting:
      final setting = SearchSetting.values.byName(item.id);
      return switch (setting) {
        SearchSetting.searchPins => const MonoSearchPinsPage(),
        SearchSetting.trainingTemplates ||
        SearchSetting.weeklyGoal ||
        SearchSetting.split => const MonoTemplatesPage(),
        _ => ProfilePage(open: profileSectionOf(setting)),
      };
  }
}
