import 'package:material_ui/material_ui.dart';

import '../../../app/formatters.dart';
import '../../../app/haptics.dart';
import '../../../data/supplements.dart';
import '../../../features/supplements/supplement_detail_page.dart';
import '../../../features/supplements/supplement_edit_sheet.dart';
import '../../../features/supplements/supplement_format.dart';
import '../../../features/supplements/supplements_page.dart'
    show supplementLine;
import '../data/mono_data.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_blocks.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_page.dart';

/// The person's supplements, the well-known ones to add, and the times of
/// the reminders, in the look.
class MonoSupplementsPage extends StatefulWidget {
  const MonoSupplementsPage({super.key});

  @override
  State<MonoSupplementsPage> createState() => _MonoSupplementsPageState();
}

class _MonoSupplementsPageState extends State<MonoSupplementsPage> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(String title) =>
      title.toLowerCase().contains(_query.text.trim().toLowerCase());

  Future<void> _pickMinute(SupplementTime time) async {
    final supplements = MonoCtx.of(context).scope.supplements;
    final minute = supplements.data.minuteOf(time);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (picked == null) return;
    await supplements.setMinute(time, picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.supplements, scope.settings, _query]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final l10n = c.l10n;
        final t = c.t;
        final data = scope.supplements.data;
        final mine = [
          for (final s in data.mine)
            if (_matches(s.title(l10n))) s,
        ];
        final keys = {for (final s in data.mine) s.key};
        final offered = [
          for (final preset in supplementCatalog)
            if (!keys.contains(preset.id) &&
                _matches(presetName(l10n, preset.id) ?? ''))
              preset,
        ];
        return MonoSubPage(
          category: MonoCategory.supplements,
          categoryLabel: l10n.supplements,
          backLabel: l10n.supplements,
          statement: data.mine.isEmpty
              ? l10n.supplementsNone
              : l10n.supplementsMine,
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: t.fill,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 22, color: t.ink2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _query,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      cursorColor: t.ink,
                      style: MonoType.body(t),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        hintText: l10n.supplementSearch,
                        hintStyle: MonoType.inter(
                          15,
                          21,
                          FontWeight.w400,
                          t.ink3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            MonoSurface(
              onTap: () {
                Haptics.tap();
                showSupplementEditSheet(context);
              },
              child: MonoRow(
                title: l10n.supplementOwn,
                leading: Icon(Icons.add_rounded, color: t.ink),
              ),
            ),
            if (mine.isNotEmpty)
              MonoBlock(
                title: l10n.supplementsMine,
                child: MonoList(
                  children: [
                    for (final s in mine)
                      Row(
                        children: [
                          Expanded(
                            child: MonoRow(
                              title: s.title(l10n),
                              subtitle: switch (supplementLine(c.formats, s)) {
                                '' => null,
                                final line => line,
                              },
                              onTap: () => c.push(
                                SupplementDetailPage(supplementKey: s.key),
                              ),
                            ),
                          ),
                          MonoIconButton(
                            icon: Icons.tune_rounded,
                            label: l10n.supplementEdit,
                            onTap: () =>
                                showSupplementEditSheet(context, existing: s),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            if (data.mine.any((s) => s.remind))
              MonoBlock(
                title: l10n.supplementReminders,
                child: MonoList(
                  children: [
                    for (final time in SupplementTime.reminded)
                      MonoRow(
                        title: time.label(l10n),
                        value: formatClock(data.minuteOf(time)),
                        onTap: () => _pickMinute(time),
                      ),
                  ],
                ),
              ),
            if (offered.isNotEmpty)
              MonoBlock(
                title: l10n.supplementsPopular,
                child: MonoList(
                  children: [
                    for (final preset in offered)
                      MonoRow(
                        title: presetName(l10n, preset.id)!,
                        leading: Icon(Icons.add_rounded, color: t.ink2),
                        onTap: () {
                          Haptics.confirm();
                          scope.supplements.addPreset(preset.id);
                        },
                      ),
                  ],
                ),
              ),
            MonoNote(l10n.supplementsNote),
          ],
        );
      },
    );
  }
}
