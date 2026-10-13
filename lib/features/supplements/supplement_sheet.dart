import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/supplement_controller.dart';
import '../../data/supplements.dart';
import '../../theme/app_shapes.dart';
import '../../widgets/entrance.dart';
import '../../widgets/segment_group.dart';
import '../entry/entry_sheet.dart';
import 'supplement_edit_sheet.dart';
import 'supplement_format.dart';
import 'supplement_row.dart';
import 'supplements_page.dart';

/// How many of the user's supplements the sheet offers at once.
const int _offered = 5;

/// What the supplement sheet was left with, where that was not a
/// [Supplement] to note as taken.
enum SupplementChoice { all, create }

/// Notes [supplement] as taken now and says so, with a way back.
Future<void> takeSupplement(BuildContext context, Supplement supplement) async {
  final supplements = AppScope.of(context).supplements;
  final l10n = Formats.of(context).l10n;
  final messenger = ScaffoldMessenger.of(context);
  final intake = await supplements.take(supplement);
  Haptics.confirm();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l10n.supplementTook(supplement.title(l10n))),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => supplements.untake(intake),
        ),
      ),
    );
}

/// Where logging a supplement starts: the user's own, most taken first,
/// then the way to all of them and to a new one. Without any of their own
/// it opens the list of all at once.
Future<void> showSupplementSheet(BuildContext context) async {
  final supplements = AppScope.of(context).supplements;
  Object? choice = supplements.data.mine.isEmpty
      ? SupplementChoice.all
      : await showAppSheet<Object>(context, (_) => const SupplementSheet());
  if (!context.mounted) return;
  if (choice == SupplementChoice.all) {
    choice = await Navigator.of(context).push(
      MaterialPageRoute<Supplement>(
        builder: (_) => const SupplementsPage(picking: true),
      ),
    );
  } else if (choice == SupplementChoice.create) {
    choice = await showSupplementEditSheet(context);
  }
  if (!context.mounted) return;
  if (choice case final Supplement supplement) {
    await takeSupplement(context, supplement);
  }
}

/// The user's supplements to tap as taken now, or to log once at another
/// time or in another dose.
class SupplementSheet extends StatelessWidget {
  const SupplementSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final theme = Theme.of(context);
    final supplements = AppScope.of(context).supplements;
    final navigator = Navigator.of(context);
    final data = supplements.data;
    final top = data.mostTaken(supplements.now).take(_offered).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.supplementAdd,
              style: context.emphasizedTextTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.supplementsOften,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final (index, supplement) in top.indexed)
              Entrance(
                order: index,
                child: ListSegment(
                  first: index == 0,
                  last: index == top.length - 1,
                  child: SupplementRow(
                    title: supplement.title(l10n),
                    line: switch (supplementLine(formats, supplement)) {
                      '' => null,
                      final line => line,
                    },
                    onTap: () => navigator.pop(supplement),
                    trailing: Icons.schedule_rounded,
                    trailingLabel: l10n.supplementOnce,
                    onTrailing: () async {
                      final done = await showAppSheet<bool>(
                        context,
                        (_) => IntakeSheet(supplement: supplement),
                      );
                      if (done == true) navigator.pop();
                    },
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: M3EFilledButton.tonal(
                    size: M3EButtonSize.md,
                    onPressed: () {
                      Haptics.tap();
                      navigator.pop(SupplementChoice.all);
                    },
                    child: Text(l10n.supplementsAll),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: M3EFilledButton(
                    size: M3EButtonSize.md,
                    onPressed: () {
                      Haptics.tap();
                      navigator.pop(SupplementChoice.create);
                    },
                    child: Text(l10n.foodNew),
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

/// Logs [supplement] once at another time of the day or in another dose
/// than its own. Pops with true once that is done.
class IntakeSheet extends StatefulWidget {
  const IntakeSheet({super.key, required this.supplement});

  final Supplement supplement;

  @override
  State<IntakeSheet> createState() => _IntakeSheetState();
}

class _IntakeSheetState extends State<IntakeSheet> {
  final TextEditingController _amount = TextEditingController();
  late DateTime _at;
  late final SupplementController _supplements;
  String? _error;
  bool _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    _supplements = AppScope.of(context).supplements;
    _at = _supplements.now;
    final amount = widget.supplement.amount;
    if (amount != null) {
      _amount.text = amountText(Formats.of(context), amount);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final now = _supplements.now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(now.year - 1, now.month, now.day),
      lastDate: now,
    );
    if (picked == null) return;
    setState(
      () => _at = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _at.hour,
        _at.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (picked == null) return;
    setState(
      () => _at = DateTime(
        _at.year,
        _at.month,
        _at.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  Future<void> _save() async {
    final l10n = Formats.of(context).l10n;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final supplement = widget.supplement;
    final text = _amount.text.trim();
    final amount = text.isEmpty ? null : parseAmount(text);
    if (text.isNotEmpty && (amount == null || amount <= 0)) {
      setState(() => _error = l10n.supplementAmountInvalid);
      return;
    }
    // The caffeine goes with the dose: twice the dose, twice of it.
    final own = supplement.amount;
    final caffeine = supplement.caffeineMg;
    final intake = await _supplements.take(
      supplement,
      at: _at,
      amount: () => amount,
      unit: () => amount == null ? null : supplement.unit,
      caffeineMg: () => caffeine != null && own != null && amount != null
          ? caffeine * amount / own
          : caffeine,
    );
    Haptics.confirm();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.supplementTook(supplement.title(l10n))),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => _supplements.untake(intake),
          ),
        ),
      );
    if (mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final supplement = widget.supplement;
    final unit = supplement.unit;
    final error = _error;
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
              supplement.title(l10n),
              style: context.emphasizedTextTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: M3EFilledButton.tonal(
                    size: M3EButtonSize.md,
                    onPressed: _pickDay,
                    child: Text(formats.relativeDay(_at, _supplements.now)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: M3EFilledButton.tonal(
                    size: M3EButtonSize.md,
                    onPressed: _pickTime,
                    child: Text(clockOf(_at)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.supplementAmount,
                suffixText: unit?.label(l10n),
                filled: true,
                border: UnderlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  borderSide: BorderSide.none,
                ),
              ),
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
            M3EFilledButton(
              size: M3EButtonSize.md,
              onPressed: _save,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
