import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../app/app_scope.dart';
import '../app/haptics.dart';
import '../app/layout.dart';
import '../theme/app_motion.dart';
import 'floating_surface.dart';
import 'glass_scope.dart';
import 'page_header.dart';
import 'sub_page.dart';
import 'tile_board.dart';
import '../l10n/generated/app_localizations.dart';

/// A top-level page: title, an optional fixed strip and a board of tiles the
/// user can rearrange. It scrolls behind the status bar; the edit pencil and
/// the [trailing] button float over it at the top right. Pulling down
/// reloads the data.
class BoardPage extends StatefulWidget {
  const BoardPage({
    super.key,
    required this.pageId,
    required this.title,
    required this.subtitle,
    required this.tiles,
    this.trailing,
    this.strip,
    this.editMenu,
    this.editFooter,
    this.footer,
    this.backdrop,
    this.backdropInk,
    this.removable = false,
  });

  /// Names the saved tile order of this page.
  final String pageId;
  final String title;
  final String subtitle;

  /// A round button of [FloatingSurface.height] that floats right of the
  /// pencil.
  final Widget? trailing;

  /// Stays under the title and is not part of the board.
  final Widget? strip;

  /// Options that are only offered while the page is being edited.
  final Widget? editMenu;

  /// Follows the board, and like [editMenu] only shows while editing.
  final Widget? editFooter;

  /// Follows the board and cannot be rearranged.
  final Widget? footer;
  final List<BoardTile> tiles;

  /// Painted behind the page from the top of the screen and scrolling with
  /// it, such as a scene that runs from edge to edge. It is given the
  /// distance from the top of the screen to the board; hidden while editing.
  final Widget Function(BuildContext context, double boardTop)? backdrop;

  /// The colour of the title while it stands on the [backdrop], for a
  /// backdrop that is dark under a light theme, such as a night sky.
  final Color? backdropInk;

  /// Gives every tile a minus while editing and lists the removed ones below
  /// the board to bring them back. A page that manages its own set of tiles
  /// leaves this off.
  final bool removable;

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  static const double _buttonGap = 8;

  bool _editing = false;

  final ScrollController _scroll = ScrollController();
  final GlobalKey _board = GlobalKey();

  /// From the top of the screen to the board, at rest.
  double? _boardTop;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _measure() {
    final box = _board.currentContext?.findRenderObject();
    if (!mounted || box is! RenderBox || !box.hasSize || _editing) return;
    final top =
        box.localToGlobal(Offset.zero).dy +
        (_scroll.hasClients ? _scroll.offset : 0);
    if (_boardTop != null && (top - _boardTop!).abs() < 0.5) return;
    setState(() => _boardTop = top);
  }

  Future<void> _refresh() async {
    await AppScope.of(context).health.refresh(full: true);
    Haptics.confirm();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final strip = widget.strip;
    final editMenu = widget.editMenu;
    final editFooter = widget.editFooter;
    final trailing = widget.trailing;
    final top = MediaQuery.paddingOf(context).top;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final backdrop = widget.backdrop;
    final boardTop = _boardTop;
    if (backdrop != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingSurface(
          glass: GlassScope.isOn(context),
          color: _editing ? scheme.primary : null,
          glassTint: _editing ? GlassScope.pillPrimary(scheme) : null,
          child: SizedBox.square(
            dimension: FloatingSurface.height,
            child: IconButton(
              onPressed: () {
                Haptics.tap();
                setState(() => _editing = !_editing);
              },
              tooltip: _editing ? l10n.done : l10n.arrangeTiles,
              color: _editing ? scheme.onPrimary : scheme.onSurfaceVariant,
              icon: Icon(_editing ? Icons.check_rounded : Icons.edit_rounded),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: _buttonGap), trailing],
      ],
    );
    final list = M3EPullToRefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        controller: _scroll,
        // Not clipped, so what scrolls out at the top is still seen behind
        // the status bar.
        clipBehavior: Clip.none,
        padding: pagePadding(context),
        children: [
          PageHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            ink: backdrop != null && boardTop != null && !_editing
                ? widget.backdropInk
                : null,
            reserved:
                _buttonGap +
                FloatingSurface.height +
                (trailing == null ? 0 : _buttonGap + FloatingSurface.height),
          ),
          if (strip != null) ...[strip, const SizedBox(height: 16)],
          if (editMenu != null)
            _EditOnly(
              editing: _editing,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: editMenu,
              ),
            ),
          ListenableBuilder(
            listenable: scope.settings,
            builder: (context, _) {
              final settings = scope.settings;
              final page = widget.pageId;
              final hidden = widget.removable
                  ? settings.hiddenTiles(page)
                  : const <String>{};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TileBoard(
                    key: _board,
                    tiles: !widget.removable
                        ? widget.tiles
                        : [
                            for (final tile in widget.tiles)
                              if (!hidden.contains(tile.id))
                                tile.withRemove(
                                  () => settings.hideTile(page, tile.id),
                                ),
                          ],
                    order: settings.tileOrder(page),
                    editing: _editing,
                    onReorder: (order) => settings.setTileOrder(page, order),
                  ),
                  if (widget.removable)
                    _EditOnly(
                      editing: _editing,
                      child: _RemovedTiles(
                        tiles: [
                          for (final tile in widget.tiles)
                            if (hidden.contains(tile.id)) tile,
                        ],
                        onAdd: (id) => settings.showTile(page, id),
                      ),
                    ),
                ],
              );
            },
          ),
          if (editFooter != null)
            _EditOnly(
              editing: _editing,
              child: Padding(
                padding: const EdgeInsets.only(top: 28),
                child: editFooter,
              ),
            ),
          ?widget.footer,
        ],
      ),
    );
    final showsBackdrop = backdrop != null && boardTop != null && !_editing;
    return Stack(
      children: [
        if (backdrop != null && boardTop != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _editing ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: ListenableBuilder(
                  listenable: _scroll,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _scroll.hasClients ? -_scroll.offset : 0),
                    child: child,
                  ),
                  child: backdrop(context, boardTop),
                ),
              ),
            ),
          ),
        // The list starts below the status bar, and with it the indicator
        // that pulling down brings out.
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: BoardBackdrop(shown: showsBackdrop, child: list),
          ),
        ),
        Positioned(top: top + SubPage.buttonTop, right: 16, child: buttons),
      ],
    );
  }
}

/// Tells the tiles of a [BoardPage] whether the page is drawing its
/// backdrop, so the tile the backdrop belongs to leaves it out.
class BoardBackdrop extends InheritedWidget {
  const BoardBackdrop({super.key, required this.shown, required super.child});

  final bool shown;

  static bool isShown(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BoardBackdrop>()?.shown ??
      false;

  /// Whether the tile [heroId] of page [pageId] gives its scene to the
  /// page, which draws it from edge to edge behind the title: the user
  /// chose that, and of the tiles [shown] the board puts it first. The ids
  /// in [inPlace] are those of tiles with [BoardTile.entersInPlace].
  static bool wanted(
    BuildContext context, {
    required String pageId,
    required String heroId,
    required List<String> shown,
    Set<String> inPlace = const {},
  }) {
    final settings = AppScope.of(context).settings;
    if (!settings.edgeToEdgeHero) return false;
    final hidden = settings.hiddenTiles(pageId);
    // The same order the board lays the tiles out in.
    final order = resolveIdOrder([
      for (final id in shown)
        if (!hidden.contains(id)) (id: id, inPlace: inPlace.contains(id)),
    ], settings.tileOrder(pageId));
    return order.firstOrNull == heroId;
  }

  @override
  bool updateShouldNotify(BoardBackdrop oldWidget) => oldWidget.shown != shown;
}

/// A scene used as a page's backdrop: it fades into the page where it ends.
class FadingBackdrop extends StatelessWidget {
  const FadingBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        stops: [0, 0.82, 1],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// Unfolds [child] with the edit mode instead of popping it in.
class _EditOnly extends StatelessWidget {
  const _EditOnly({required this.editing, required this.child});

  final bool editing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      value: editing ? 1 : 0,
      motion: AppMotion.spatialFast,
      // Folded away, it is not built at all.
      builder: (context, t, child) => t <= 0.001 && !editing
          ? const SizedBox.shrink()
          : ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: t < 0 ? 0 : t,
                child: Opacity(opacity: t.clamp(0, 1).toDouble(), child: child),
              ),
            ),
      child: ExcludeFocus(
        excluding: !editing,
        child: IgnorePointer(ignoring: !editing, child: child),
      ),
    );
  }
}

/// The tiles the user took off the page, each with a plus.
class _RemovedTiles extends StatelessWidget {
  const _RemovedTiles({required this.tiles, required this.onAdd});

  final List<BoardTile> tiles;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(AppLocalizations.of(context).add),
        M3ESegmentedColumn(
          color: scheme.surfaceBright,
          haptic: M3EHapticFeedback.light,
          onTap: (i) => onAdd(tiles[i].id),
          children: [
            for (final tile in tiles)
              M3EListItem(
                headline: Text(tile.title ?? tile.id),
                trailing: Icon(Icons.add_circle_rounded, color: scheme.primary),
              ),
          ],
        ),
      ],
    );
  }
}
