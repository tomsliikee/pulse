import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/haptics.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_shapes.dart';

/// "7.3.1992".
String formatBirthDate(DateTime date) =>
    '${date.day}.${date.month}.${date.year}';

/// Reads "7.3.1992" and "07.03.1992". Null for anything that is not a day
/// of the calendar, such as 31.2.
DateTime? parseBirthDate(String text) {
  final parts = text.trim().split('.');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0].trim());
  final month = int.tryParse(parts[1].trim());
  final year = int.tryParse(parts[2].trim());
  if (day == null || month == null || year == null) return null;
  final date = DateTime(year, month, day);
  // DateTime rolls 31.2. over into March instead of refusing it.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// Asks for the date of birth as text. The framework's date picker would be
/// English here, because the app carries no localisations.
Future<void> showBirthDateSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _BirthDateSheet(),
);

class _BirthDateSheet extends StatefulWidget {
  const _BirthDateSheet();

  @override
  State<_BirthDateSheet> createState() => _BirthDateSheetState();
}

class _BirthDateSheetState extends State<_BirthDateSheet> {
  TextEditingController? _controller;
  bool _invalid = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = AppScope.of(context).settings.birthDate;
    _controller ??= TextEditingController(
      text: current == null ? '' : formatBirthDate(current),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _save() {
    final date = parseBirthDate(_controller!.text);
    if (date == null || !isPlausibleBirthDate(date)) {
      setState(() => _invalid = true);
      return;
    }
    AppScope.of(context).settings.setBirthDate(date);
    Haptics.confirm();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            'Geburtsdatum',
            style: context.emphasizedTextTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.datetime,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'TT.MM.JJJJ',
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.large),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_invalid) ...[
            const SizedBox(height: 12),
            Text(
              'Bitte ein Datum wie 7.3.1992 eingeben.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 20),
          M3EFilledButton(
            size: M3EButtonSize.md,
            onPressed: _save,
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
