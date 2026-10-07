import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../data/settings_controller.dart';
import '../../l10n/generated/app_localizations.dart';

/// A language is named in itself, so it can be found from any other.
String languageName(String code) => switch (code) {
  'de' => 'Deutsch',
  'pl' => 'Polski',
  _ => 'English',
};

/// The languages in the order they are offered.
const List<String> _offered = ['de', 'en', 'pl'];

/// Lets the user follow the system's language or pick one of the app's.
Future<void> showLanguageSheet(BuildContext context) {
  // The system's settings may have changed the choice since it was read.
  AppScope.of(context).language.refresh();
  return showModalBottomSheet<void>(
    context: context,
    // Four rows are taller than the half screen a sheet gets otherwise.
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    assert(_offered.length == appLanguages.length);
    final language = AppScope.of(context).language;
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: language,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final choices = <String?>[null, ..._offered];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.language,
                  style: context.emphasizedTextTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                M3ESegmentedColumn(
                  color: scheme.surfaceBright,
                  haptic: M3EHapticFeedback.light,
                  onTap: (i) => language.choose(choices[i]),
                  children: [
                    for (final code in choices)
                      M3EListItem(
                        headline: Text(
                          code == null
                              ? l10n.languageSystem
                              : languageName(code),
                        ),
                        trailing: code == language.choice
                            ? Icon(Icons.check_rounded, color: scheme.primary)
                            : null,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
