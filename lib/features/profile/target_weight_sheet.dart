import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_shapes.dart';
import '../../l10n/generated/app_localizations.dart';

/// Reads a weight in kilograms to one decimal; "100", "100 kg" and "99,5"
/// all give one. Null for anything outside what the profile accepts.
double? parseTargetWeightKg(String text) {
  final number = double.tryParse(
    text.toLowerCase().replaceAll('kg', '').replaceAll(',', '.').trim(),
  );
  if (number == null || !number.isFinite) return null;
  final kg = (number * 10).round() / 10;
  return kg >= minTargetWeightKg && kg <= maxTargetWeightKg ? kg : null;
}

/// Asks for the weight to reach as text. An empty field takes it away again.
Future<void> showTargetWeightSheet(BuildContext context) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _TargetWeightSheet(),
    );

class _TargetWeightSheet extends StatefulWidget {
  const _TargetWeightSheet();

  @override
  State<_TargetWeightSheet> createState() => _TargetWeightSheetState();
}

class _TargetWeightSheetState extends State<_TargetWeightSheet> {
  TextEditingController? _controller;
  bool _invalid = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = AppScope.of(context).settings.targetWeightKg;
    _controller ??= TextEditingController(
      text: current == null ? '' : Formats.of(context).decimal(current),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller!.text.trim();
    final weight = parseTargetWeightKg(text);
    if (weight == null && text.isNotEmpty) {
      setState(() => _invalid = true);
      return;
    }
    AppScope.of(context).settings.setTargetWeightKg(weight);
    Haptics.confirm();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.targetWeightLabel,
            style: context.emphasizedTextTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: l10n.targetWeightHint,
              filled: true,
              border: UnderlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.large),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_invalid) ...[
            const SizedBox(height: 12),
            Text(
              l10n.targetWeightInvalid,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
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
    );
  }
}
