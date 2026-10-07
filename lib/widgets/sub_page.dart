import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../app/haptics.dart';
import '../theme/app_motion.dart';
import 'floating_surface.dart';

/// A page opened from another one. It has no app bar: the content scrolls
/// behind the status bar, a round back button floats over it, and once the
/// large title has scrolled away a pill with the [title] appears next to
/// the button.
class SubPage extends StatefulWidget {
  const SubPage({
    super.key,
    required this.title,
    this.child,
    this.slivers,
    this.largeTitle,
    this.glass = false,
    this.bottomPadding = 32,
    this.overlay,
  }) : assert((child == null) != (slivers == null));

  final String title;

  /// Shown at the top of the content instead of the [title] in large type.
  /// The pill appears when this has scrolled away.
  final Widget? largeTitle;

  /// The content, laid out as a whole.
  final Widget? child;

  /// The content as slivers instead of [child], for a long list that is
  /// built as it scrolls into view.
  final List<Widget>? slivers;

  /// Draws the back button and the pill as liquid glass.
  final bool glass;

  /// Space the content leaves free at its end.
  final double bottomPadding;

  /// Floats over the content, like a bar at the bottom of the page.
  final Widget? overlay;

  /// Space between the status bar and the floating buttons of a page.
  static const double buttonTop = 8;

  @override
  State<SubPage> createState() => _SubPageState();
}

class _SubPageState extends State<SubPage> {
  static const double _titleGap = 12;

  final ScrollController _scroll = ScrollController();
  final GlobalKey _titleKey = GlobalKey();
  final ValueNotifier<bool> _pill = ValueNotifier(false);
  double _titleHeight = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pill.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Scrolled far away the title is no longer laid out, so its last height
    // is kept.
    final box = _titleKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) _titleHeight = box.size.height;
    if (_titleHeight == 0) return;
    // The title has left the row of the button and is behind the status bar.
    _pill.value =
        _scroll.offset > _titleGap + _titleHeight + FloatingSurface.height;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top + SubPage.buttonTop;
    final overlay = widget.overlay;
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  top: top + FloatingSurface.height + _titleGap,
                ),
                sliver: SliverToBoxAdapter(
                  child: KeyedSubtree(
                    key: _titleKey,
                    child:
                        widget.largeTitle ??
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: Text(
                            widget.title,
                            style: context.emphasizedTextTheme.headlineMedium
                                ?.copyWith(color: theme.colorScheme.onSurface),
                          ),
                        ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, widget.bottomPadding),
                sliver: switch (widget.slivers) {
                  final slivers? => SliverMainAxisGroup(slivers: slivers),
                  null => SliverToBoxAdapter(child: widget.child),
                },
              ),
            ],
          ),
          ?overlay,
          Positioned(
            top: top,
            left: 16,
            right: 16,
            child: Row(
              children: [
                FloatingSurface(
                  glass: widget.glass,
                  child: SizedBox.square(
                    dimension: FloatingSurface.height,
                    child: BackButton(
                      onPressed: () {
                        Haptics.tap();
                        Navigator.maybePop(context);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: ValueListenableBuilder(
                    valueListenable: _pill,
                    builder: (context, shown, _) => _TitlePill(
                      title: widget.title,
                      glass: widget.glass,
                      shown: shown,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The name of the page in a pill. Hidden, it is not built at all.
class _TitlePill extends StatelessWidget {
  const _TitlePill({
    required this.title,
    required this.glass,
    required this.shown,
  });

  final String title;
  final bool glass;
  final bool shown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleMotionBuilder(
      value: shown ? 1 : 0,
      motion: AppMotion.spatialFast,
      builder: (context, t, child) => t <= 0.001 && !shown
          ? const SizedBox.shrink()
          : Opacity(
              opacity: t.clamp(0, 1).toDouble(),
              child: Transform.scale(
                scale: 0.9 + 0.1 * t,
                alignment: Alignment.centerLeft,
                child: child,
              ),
            ),
      child: IgnorePointer(
        child: FloatingSurface(
          glass: glass,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              widthFactor: 1,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.emphasizedTextTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
