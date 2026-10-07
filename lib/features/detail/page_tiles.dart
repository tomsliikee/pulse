import 'package:material_ui/material_ui.dart';

import '../../data/health_controller.dart';
import '../../data/metric_catalog.dart';
import '../../data/settings_controller.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/tile_board.dart';
import 'large_metric_tile.dart';
import 'metric_spec.dart';
import '../../app/formatters.dart';

/// The name under which the large form of [metric] on [page] is saved.
String pageTileId(String page, Metric metric) => '$page/${metric.name}';

/// A compact tile for [metric] on the selected day; opens its detail page.
///
/// With [settings] and [page] the user can switch it to the large form, the
/// same one the Today page has.
BoardTile statTile(
  BuildContext context,
  HealthController health,
  Metric metric, {
  TileSpan span = TileSpan.half,
  String? title,
  SettingsController? settings,
  String? page,
}) {
  final spec = metric.spec;
  final formats = Formats.of(context);
  final label = title ?? metric.title(formats.l10n);
  final sizeId = page == null ? null : pageTileId(page, metric);
  final resize = settings == null || sizeId == null
      ? null
      : () => settings.toggleTileSize(sizeId);
  if (settings != null && sizeId != null && settings.isLargeTile(sizeId)) {
    return BoardTile(
      id: metric.name,
      title: label,
      height: 272,
      large: true,
      onResize: resize,
      child: LargeMetricTile(
        metric: metric,
        title: label,
        health: health,
        settings: settings,
        dayIndex: health.selectedIndex,
      ),
    );
  }
  return BoardTile(
    id: metric.name,
    title: label,
    span: span,
    height: 132,
    onResize: resize,
    child: StatTile(
      label: label,
      value: span == TileSpan.third
          ? metric.format(formats, health.value(metric))
          : metric.formatWithUnit(formats, health.value(metric)),
      number: health.value(metric),
      format: (value) => span == TileSpan.third
          ? metric.format(formats, value)
          : metric.formatWithUnit(formats, value),
      icon: spec.icon,
      shape: spec.shape,
      tone: spec.tone,
      onTap: (origin) => openMetric(context, metric, origin),
    ),
  );
}
