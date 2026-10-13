import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../app/morning_notices.dart';
import '../../data/supplements.dart';
import '../../theme/app_shapes.dart';
import '../entry/entry_sheet.dart';
import 'supplement_format.dart';

/// Opens the form for a supplement of the user's own, or for changing
/// [existing]. Completes with the supplement as saved, or null when the
/// sheet was left or the supplement removed.
Future<Supplement?> showSupplementEditSheet(
  BuildContext context, {
  Supplement? existing,
}) => showAppSheet<Supplement>(
  context,
  (_) => SupplementEditSheet(existing: existing),
);

/// Name, dose, caffeine, time of day and reminder of one supplement.
class SupplementEditSheet extends StatefulWidget {
  const SupplementEditSheet({super.key, this.existing});

  final Supplement? existing;

  @override
  State<SupplementEditSheet> createState() => _SupplementEditSheetState();
}

class _SupplementEditSheetState extends State<SupplementEditSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _caffeine = TextEditingController();
  SupplementUnit? _unit;
  SupplementTime _time = SupplementTime.any;
  bool _remind = false;
  String? _error;
  bool _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Here and not in initState: the decimal sign is the language's.
    if (_filled) return;
    _filled = true;
    final existing = widget.existing;
    if (existing == null) return;
    final formats = Formats.of(context);
    String text(double? value) =>
        value == null ? '' : amountText(formats, value);
    _name.text = existing.name ?? '';
    _amount.text = text(existing.amount);
    _caffeine.text = text(existing.caffeineMg);
    _unit = existing.unit;
    _time = existing.time;
    _remind = existing.remind;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _caffeine.dispose();
    super.dispose();
  }

  /// An empty field is valid and means "not given".
  ({bool valid, double? value}) _number(TextEditingController field) {
    final text = field.text.trim();
    if (text.isEmpty) return (valid: true, value: null);
    final value = parseAmount(text);
    return (valid: value != null && value > 0 && value <= 100000, value: value);
  }

  Future<void> _save() async {
    final scope = AppScope.of(context);
    final l10n = Formats.of(context).l10n;
    final navigator = Navigator.of(context);
    final existing = widget.existing;
    final name = _name.text.trim();
    final own = existing == null || existing.preset == null;
    if (own && name.isEmpty) {
      setState(() => _error = l10n.supplementNameMissing);
      return;
    }
    final amount = _number(_amount);
    final caffeine = _number(_caffeine);
    if (!amount.valid || !caffeine.valid) {
      setState(() => _error = l10n.supplementAmountInvalid);
      return;
    }
    final remind = _remind && _time != SupplementTime.any;
    final base =
        existing ??
        // One of the same name that was removed comes back with its past.
        scope.supplements.data.byKey(ownSupplementKey(name)) ??
        Supplement(key: ownSupplementKey(name), addedAt: scope.supplements.now);
    final saved = base.copyWith(
      name: own ? name : null,
      amount: () => amount.value,
      unit: () => amount.value == null ? null : _unit,
      caffeineMg: () => caffeine.value,
      time: _time,
      remind: remind,
      removedAt: () => null,
    );
    await scope.supplements.save(saved);
    // Asked where the reminder is switched on, not at the first start.
    if (remind && existing?.remind != true) await MorningNotices.allow();
    Haptics.confirm();
    if (mounted) navigator.pop(saved);
  }

  Future<void> _remove(Supplement supplement) async {
    final scope = AppScope.of(context);
    final l10n = Formats.of(context).l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await scope.supplements.remove(supplement.key);
    Haptics.confirm();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.supplementRemoved(supplement.title(l10n))),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => scope.supplements.save(supplement),
          ),
        ),
      );
    if (mounted) navigator.pop();
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    border: UnderlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.large),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = Formats.of(context).l10n;
    final existing = widget.existing;
    const number = TextInputType.numberWithOptions(decimal: true);
    final error = _error;
    final count = parseAmount(_amount.text) ?? 2;
    const times = SupplementTime.values;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing == null
                  ? l10n.supplementOwn
                  : existing.preset == null
                  ? l10n.supplementEdit
                  : existing.title(l10n),
              style: context.emphasizedTextTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            if (existing == null || existing.preset == null) ...[
              TextField(
                controller: _name,
                // The key is the name, so one that exists keeps its name.
                enabled: existing == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration(l10n.supplementName),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _amount,
              keyboardType: number,
              onChanged: (_) => setState(() {}),
              decoration: _decoration(l10n.supplementAmount),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final unit in SupplementUnit.values)
                  ChoiceChip(
                    label: Text(unit.label(l10n, count)),
                    selected: _unit == unit,
                    onSelected: (on) {
                      Haptics.selection();
                      setState(() => _unit = on ? unit : null);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _caffeine,
              keyboardType: number,
              decoration: _decoration(l10n.supplementCaffeine),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final time in times)
                  ChoiceChip(
                    label: Text(time.label(l10n)),
                    selected: _time == time,
                    onSelected: (_) {
                      Haptics.selection();
                      setState(() => _time = time);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.supplementRemind,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        l10n.supplementRemindNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _remind && _time != SupplementTime.any,
                  onChanged: _time == SupplementTime.any
                      ? null
                      : (value) {
                          Haptics.selection();
                          setState(() => _remind = value);
                        },
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (existing != null && !existing.removed) ...[
                  Expanded(
                    child: M3EFilledButton.tonal(
                      size: M3EButtonSize.md,
                      onPressed: () => _remove(existing),
                      child: Text(l10n.remove),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: M3EFilledButton(
                    size: M3EButtonSize.md,
                    onPressed: _save,
                    child: Text(l10n.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
