import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../app/app_scope.dart';
import '../app/haptics.dart';
import '../app/layout.dart';
import '../theme/app_motion.dart';
import 'page_header.dart';
import 'tile_board.dart';
import '../l10n/generated/app_localizations.dart';

/// A top-level page: title with the edit pencil, an optional fixed strip and
/// a board of tiles the user can rearrange. Pulling down reloads the data.
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
    this.removable = false,
  });

  /// Names the saved tile order of this page.
  final String pageId;
  final String title;
  final String subtitle;
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

  /// Gives every tile a minus while editing and lists the removed ones below
  /// the board to bring them back. A page that manages its own set of tiles
  /// leaves this off.
  final bool removable;

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  bool _editing = false;

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
    return M3EPullToRefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: pagePadding(context),
        children: [
          PageHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            trailing: widget.trailing,
            editing: _editing,
            onToggleEditing: () => setState(() => _editing = !_editing),
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
