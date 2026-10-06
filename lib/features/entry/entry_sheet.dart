import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/models.dart';
import '../../theme/app_shapes.dart';

/// Opens the form that records a new entry of [kind], or changes [existing].
Future<void> showEntrySheet(
  BuildContext context,
  EntryKind kind, {
  HealthEntry? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => EntrySheet(kind: kind, existing: existing),
  );
}

/// Accepts both "72,5" and "72.5".
double? parseAmount(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

extension EntryKindLabel on EntryKind {
  String get label => switch (this) {
    EntryKind.water => 'Wasser',
    EntryKind.weight => 'Gewicht',
    EntryKind.meal => 'Mahlzeit',
  };

  String get amountLabel => switch (this) {
    EntryKind.water => 'Menge in ml',
    EntryKind.weight => 'Gewicht in kg',
    EntryKind.meal => 'Kalorien in kcal',
  };

  /// The range a value must lie in to be saved.
  (double, double) get range => switch (this) {
    EntryKind.water => (10, 5000),
    EntryKind.weight => (2, 500),
    EntryKind.meal => (1, 10000),
  };
}

class EntrySheet extends StatefulWidget {
  const EntrySheet({super.key, required this.kind, this.existing});

  final EntryKind kind;
  final HealthEntry? existing;

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  static const _quickWater = [200, 300, 500];
  static const _nutrientMax = 1000.0;

  late final TextEditingController _amount = TextEditingController(
    text: _initial(widget.existing?.draft.amount),
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.draft.name ?? '',
  );
  late final Map<String, TextEditingController> _nutrients = {
    'Kohlenhydrate': TextEditingController(
      text: _initial(widget.existing?.draft.carbs),
    ),
    'Eiweiss': TextEditingController(
      text: _initial(widget.existing?.draft.protein),
    ),
    'Fett': TextEditingController(text: _initial(widget.existing?.draft.fat)),
    'Ballaststoffe': TextEditingController(
      text: _initial(widget.existing?.draft.fiber),
    ),
    'Zucker': TextEditingController(
      text: _initial(widget.existing?.draft.sugar),
    ),
  };

  String? _error;
  bool _saving = false;

  static String _initial(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.round().toString()
        : formatDecimal(value);
  }

  @override
  void dispose() {
    _amount.dispose();
    _name.dispose();
    for (final controller in _nutrients.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// An empty field is valid and means "not given".
  ({bool valid, double? value}) _nutrient(String label) {
    final text = _nutrients[label]!.text.trim();
    if (text.isEmpty) return (valid: true, value: null);
    final value = parseAmount(text);
    final valid = value != null && value >= 0 && value <= _nutrientMax;
    return (valid: valid, value: value);
  }

  Future<void> _save() async {
    final kind = widget.kind;
    final (min, max) = kind.range;
    final amount = parseAmount(_amount.text);
    if (amount == null || amount < min || amount > max) {
      setState(
        () => _error =
            'Bitte eine Zahl zwischen ${formatInt(min.round())} und '
            '${formatInt(max.round())} eingeben.',
      );
      return;
    }
    final parts = {
      for (final label in _nutrients.keys) label: _nutrient(label),
    };
    if (parts.values.any((p) => !p.valid)) {
      setState(
        () => _error = 'Nährwerte müssen Zahlen zwischen 0 und 1.000 g sein.',
      );
      return;
    }

    final name = _name.text.trim();
    final draft = EntryDraft(
      kind: kind,
      time: widget.existing?.draft.time ?? DateTime.now(),
      amount: amount,
      name: kind == EntryKind.meal && name.isNotEmpty ? name : null,
      carbs: parts['Kohlenhydrate']!.value,
      protein: parts['Eiweiss']!.value,
      fat: parts['Fett']!.value,
      fiber: parts['Ballaststoffe']!.value,
      sugar: parts['Zucker']!.value,
    );

    final health = AppScope.of(context).health;
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existing = widget.existing;
      if (existing == null) {
        await health.addEntry(draft);
      } else {
        await health.replaceEntry(existing, draft);
      }
      Haptics.confirm();
      if (mounted) navigator.pop();
    } on Exception {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Der Eintrag konnte nicht gespeichert werden.';
      });
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.large),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = widget.kind;
    const number = TextInputType.numberWithOptions(decimal: true);
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
              widget.existing == null
                  ? '${kind.label} eintragen'
                  : '${kind.label} bearbeiten',
              style: context.emphasizedTextTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            if (kind == EntryKind.water) ...[
              Row(
                children: [
                  for (final ml in _quickWater) ...[
                    if (ml != _quickWater.first) const SizedBox(width: 8),
                    Expanded(
                      child: M3EFilledButton.tonal(
                        onPressed: () {
                          Haptics.selection();
                          setState(() => _amount.text = ml.toString());
                        },
                        child: Text('$ml ml'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (kind == EntryKind.meal) ...[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration('Name (optional)'),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _amount,
              keyboardType: number,
              decoration: _decoration(kind.amountLabel),
            ),
            if (kind == EntryKind.meal)
              for (final MapEntry(key: label, value: controller)
                  in _nutrients.entries) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: number,
                  decoration: _decoration('$label in g (optional)'),
                ),
              ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            M3EFilledButton(
              size: M3EButtonSize.md,
              enabled: !_saving,
              onPressed: _save,
              child: Text(_saving ? 'Speichert …' : 'Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}
