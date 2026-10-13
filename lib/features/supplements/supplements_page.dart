import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/supplements.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_shapes.dart';
import '../../widgets/page_header.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/sub_page.dart';
import 'supplement_detail_page.dart';
import 'supplement_edit_sheet.dart';
import 'supplement_format.dart';
import 'supplement_row.dart';

/// "1 Scoop · Morgens", or only what is set of the two.
String supplementLine(Formats formats, Supplement supplement) => [
  ?doseText(formats, supplement.amount, supplement.unit),
  if (supplement.time != SupplementTime.any)
    supplement.time.label(formats.l10n),
  if (supplement.caffeineMg case final mg?)
    '${amountText(formats, mg)} mg ${formats.l10n.metricCaffeine}',
].join(' · ');

/// The user's supplements, the well-known ones to add, and the times of
/// the reminders. With [picking], a tap pops with the [Supplement] taken,
/// a preset being put on the list first.
class SupplementsPage extends StatefulWidget {
  const SupplementsPage({super.key, this.picking = false});

  final bool picking;

  @override
  State<SupplementsPage> createState() => _SupplementsPageState();
}

class _SupplementsPageState extends State<SupplementsPage> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(String title) =>
      title.toLowerCase().contains(_query.text.trim().toLowerCase());

  Future<void> _pickMinute(SupplementTime time) async {
    final supplements = AppScope.of(context).supplements;
    final minute = supplements.data.minuteOf(time);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (picked == null) return;
    await supplements.setMinute(time, picked.hour * 60 + picked.minute);
  }

  Future<void> _addPreset(SupplementPreset preset) async {
    final navigator = Navigator.of(context);
    final supplements = AppScope.of(context).supplements;
    Haptics.confirm();
    final added = await supplements.addPreset(preset.id);
    if (widget.picking && mounted) navigator.pop(added);
  }

  Future<void> _create() async {
    final navigator = Navigator.of(context);
    final created = await showSupplementEditSheet(context);
    if (created != null && widget.picking && mounted) navigator.pop(created);
  }

  void _open(Supplement supplement) {
    if (widget.picking) {
      Navigator.of(context).pop(supplement);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SupplementDetailPage(supplementKey: supplement.key),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.supplements, scope.settings, _query]),
      builder: (context, _) {
        final formats = Formats.of(context);
        final l10n = formats.l10n;
        final data = scope.supplements.data;
        final mine = [
          for (final supplement in data.mine)
            if (_matches(supplement.title(l10n))) supplement,
        ];
        final keys = {for (final supplement in data.mine) supplement.key};
        final offered = [
          for (final preset in supplementCatalog)
            if (!keys.contains(preset.id) &&
                _matches(presetName(l10n, preset.id) ?? ''))
              preset,
        ];
        return SubPage(
          title: l10n.supplements,
          glass: scope.settings.liquidGlass,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.supplementSearch,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _query.clear,
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.large),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  M3EFilledButton.tonal(
                    size: M3EButtonSize.md,
                    onPressed: () {
                      Haptics.tap();
                      _create();
                    },
                    child: Text(l10n.supplementOwn),
                  ),
                  if (mine.isNotEmpty) SectionTitle(l10n.supplementsMine),
                ],
              ),
            ),
            SliverList.builder(
              itemCount: mine.length,
              itemBuilder: (context, index) {
                final supplement = mine[index];
                final line = supplementLine(formats, supplement);
                return ListSegment(
                  first: index == 0,
                  last: index == mine.length - 1,
                  child: SupplementRow(
                    title: supplement.title(l10n),
                    line: line.isEmpty ? null : line,
                    onTap: () => _open(supplement),
                    trailing: widget.picking
                        ? Icons.add_rounded
                        : Icons.tune_rounded,
                    onTrailing: widget.picking
                        ? null
                        : () => showSupplementEditSheet(
                            context,
                            existing: supplement,
                          ),
                    trailingLabel: l10n.supplementEdit,
                  ),
                );
              },
            ),
            if (!widget.picking && data.mine.any((s) => s.remind))
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionTitle(l10n.supplementReminders),
                    M3ESegmentedColumn(
                      color: scheme.surfaceBright,
                      haptic: M3EHapticFeedback.light,
                      onTap: (i) => _pickMinute(SupplementTime.reminded[i]),
                      children: [
                        for (final time in SupplementTime.reminded)
                          M3EListItem(
                            headline: Text(time.label(l10n)),
                            trailing: Text(
                              formatClock(data.minuteOf(time)),
                              style: context.emphasizedTextTheme.titleMedium
                                  ?.copyWith(color: scheme.primary),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (offered.isNotEmpty)
              SliverToBoxAdapter(child: SectionTitle(l10n.supplementsPopular)),
            SliverList.builder(
              itemCount: offered.length,
              itemBuilder: (context, index) {
                final preset = offered[index];
                return ListSegment(
                  first: index == 0,
                  last: index == offered.length - 1,
                  child: SupplementRow(
                    title: presetName(l10n, preset.id)!,
                    onTap: () => _addPreset(preset),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(child: _Note(l10n: l10n)),
          ],
        );
      },
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 0),
      child: Text(
        l10n.supplementsNote,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
