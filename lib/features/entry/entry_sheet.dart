import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/back_gesture.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../theme/app_shapes.dart';
import '../detail/metric_spec.dart';
import '../../l10n/generated/app_localizations.dart';

/// Opens the form that records a new entry of [kind], or changes [existing].
Future<void> showEntrySheet(
  BuildContext context,
  EntryKind kind, {
  HealthEntry? existing,
}) {
  final navigator = Navigator.of(context);
  final localizations = MaterialLocalizations.of(context);
  return navigator.push(
    _EntrySheetRoute(
      builder: (_) => EntrySheet(kind: kind, existing: existing),
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
    ),
  );
}

/// The modal sheet of `showModalBottomSheet`, which also shrinks towards the
/// bottom edge while a back swipe is in progress.
class _EntrySheetRoute extends ModalBottomSheetRoute<void>
    with BackGestureRoute<void> {
  _EntrySheetRoute({
    required super.builder,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.modalBarrierColor,
  }) : super(isScrollControlled: true, showDragHandle: true);

  static final _scale = Tween<double>(begin: 1, end: 0.9);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => ScaleTransition(
    scale: backProgress.drive(_scale),
    alignment: Alignment.bottomCenter,
    child: super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    ),
  );
}

/// Accepts both "72,5" and "72.5".
double? parseAmount(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

extension EntryKindLabel on EntryKind {
  String label(AppLocalizations l10n) => switch (this) {
    EntryKind.water => l10n.metricWater,
    EntryKind.weight => l10n.metricWeight,
    EntryKind.meal => l10n.entryMeal,
  };

  String addTitle(AppLocalizations l10n) => switch (this) {
    EntryKind.water => l10n.addWater,
    EntryKind.weight => l10n.addWeight,
    EntryKind.meal => l10n.addMeal,
  };

  String editTitle(AppLocalizations l10n) => switch (this) {
    EntryKind.water => l10n.editWater,
    EntryKind.weight => l10n.editWeight,
    EntryKind.meal => l10n.editMeal,
  };

  String amountLabel(AppLocalizations l10n) => switch (this) {
    EntryKind.water => l10n.amountWater,
    EntryKind.weight => l10n.amountWeight,
    EntryKind.meal => l10n.amountMeal,
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

  final TextEditingController _amount = TextEditingController();
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.draft.name ?? '',
  );
  final Map<Metric, TextEditingController> _nutrients = {
    for (final metric in const [
      Metric.carbs,
      Metric.protein,
      Metric.fat,
      Metric.fiber,
      Metric.sugar,
    ])
      metric: TextEditingController(),
  };

  String? _error;
  bool _saving = false;
  bool _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Here and not in initState: the decimal sign is the language's.
    if (_filled) return;
    _filled = true;
    final formats = Formats.of(context);
    String initial(double? value) {
      if (value == null) return '';
      return value == value.roundToDouble()
          ? value.round().toString()
          : formats.decimal(value);
    }

    final draft = widget.existing?.draft;
    _amount.text = initial(draft?.amount);
    _nutrients[Metric.carbs]!.text = initial(draft?.carbs);
    _nutrients[Metric.protein]!.text = initial(draft?.protein);
    _nutrients[Metric.fat]!.text = initial(draft?.fat);
    _nutrients[Metric.fiber]!.text = initial(draft?.fiber);
    _nutrients[Metric.sugar]!.text = initial(draft?.sugar);
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
  ({bool valid, double? value}) _nutrient(Metric metric) {
    final text = _nutrients[metric]!.text.trim();
    if (text.isEmpty) return (valid: true, value: null);
    final value = parseAmount(text);
    final valid = value != null && value >= 0 && value <= _nutrientMax;
    return (valid: valid, value: value);
  }

  Future<void> _save() async {
    final kind = widget.kind;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final (min, max) = kind.range;
    final amount = parseAmount(_amount.text);
    if (amount == null || amount < min || amount > max) {
      setState(
        () => _error = l10n.numberBetween(
          formats.integer(min.round()),
          formats.integer(max.round()),
        ),
      );
      return;
    }
    final parts = {
      for (final metric in _nutrients.keys) metric: _nutrient(metric),
    };
    if (parts.values.any((p) => !p.valid)) {
      setState(
        () =>
            _error = l10n.nutrientsRange(formats.integer(_nutrientMax.round())),
      );
      return;
    }

    final name = _name.text.trim();
    final draft = EntryDraft(
      kind: kind,
      time: widget.existing?.draft.time ?? DateTime.now(),
      amount: amount,
      name: kind == EntryKind.meal && name.isNotEmpty ? name : null,
      carbs: parts[Metric.carbs]!.value,
      protein: parts[Metric.protein]!.value,
      fat: parts[Metric.fat]!.value,
      fiber: parts[Metric.fiber]!.value,
      sugar: parts[Metric.sugar]!.value,
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
        _error = l10n.entrySaveFailed;
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
    final l10n = AppLocalizations.of(context);
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
                  ? kind.addTitle(l10n)
                  : kind.editTitle(l10n),
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
                decoration: _decoration(l10n.nameOptional),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _amount,
              keyboardType: number,
              decoration: _decoration(kind.amountLabel(l10n)),
            ),
            if (kind == EntryKind.meal)
              for (final MapEntry(key: metric, value: controller)
                  in _nutrients.entries) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: number,
                  decoration: _decoration(
                    l10n.nutrientInGrams(metric.title(l10n)),
                  ),
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
              child: Text(_saving ? l10n.saving : l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
