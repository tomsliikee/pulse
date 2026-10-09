import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/haptics.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_shapes.dart';
import '../../l10n/generated/app_localizations.dart';

/// Asks what the app should call the user. An empty field takes the name
/// away again.
Future<void> showNameSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _NameSheet(),
);

class _NameSheet extends StatefulWidget {
  const _NameSheet();

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  TextEditingController? _controller;
  bool _invalid = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= TextEditingController(
      text: AppScope.of(context).settings.name ?? '',
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller!.text.trim();
    if (text.length > maxNameLength) {
      setState(() => _invalid = true);
      return;
    }
    AppScope.of(context).settings.setName(text);
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
            l10n.nameLabel,
            style: context.emphasizedTextTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: l10n.nameLabel,
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
              l10n.nameInvalid,
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
