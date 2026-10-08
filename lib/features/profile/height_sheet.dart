import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/haptics.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_shapes.dart';
import '../../l10n/generated/app_localizations.dart';

/// Reads a height in whole centimetres; "181", "181 cm" and "181,4" all
/// give one. Null for anything outside what the profile accepts.
int? parseHeightCm(String text) {
  final number = double.tryParse(
    text.toLowerCase().replaceAll('cm', '').replaceAll(',', '.').trim(),
  );
  if (number == null || !number.isFinite) return null;
  final cm = number.round();
  return cm >= minHeightCm && cm <= maxHeightCm ? cm : null;
}

/// Asks for the height as text. An empty field takes the height away again.
Future<void> showHeightSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _HeightSheet(),
);

class _HeightSheet extends StatefulWidget {
  const _HeightSheet();

  @override
  State<_HeightSheet> createState() => _HeightSheetState();
}

class _HeightSheetState extends State<_HeightSheet> {
  TextEditingController? _controller;
  bool _invalid = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = AppScope.of(context).settings.heightCm;
    _controller ??= TextEditingController(text: current?.toString() ?? '');
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller!.text.trim();
    final height = parseHeightCm(text);
    if (height == null && text.isNotEmpty) {
      setState(() => _invalid = true);
      return;
    }
    AppScope.of(context).settings.setHeightCm(height);
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
            l10n.heightLabel,
            style: context.emphasizedTextTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: l10n.heightHint,
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
              l10n.heightInvalid,
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
