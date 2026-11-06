import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../pages/browse_page.dart';
import '../pages/insights_page.dart';
import '../pages/longevity_page.dart';
import '../theme/mono_tokens.dart';
import '../widgets/mono_add_menu.dart';
import '../widgets/mono_floating_bar.dart';
import '../widgets/mono_icons.dart';

/// The home of the look: three pages — Insights, Longevity and Browse — the
/// floating bar with its +, and on Browse the search above it.
class MonoShell extends StatefulWidget {
  const MonoShell({super.key});

  @override
  State<MonoShell> createState() => _MonoShellState();
}

class _MonoShellState extends State<MonoShell> {
  int _index = 0;
  final Set<int> _opened = {0};
  final ValueNotifier<String> _query = ValueNotifier('');

  static const int _browse = 2;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _open(int index) {
    // The keyboard of the search does not follow to another page.
    if (index != _browse) FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _index = index;
      _opened.add(index);
    });
  }

  Widget _page(int index) => switch (index) {
    0 => MonoInsightsPage(onOpenBrowse: () => _open(_browse)),
    1 => const MonoLongevityPage(),
    _ => MonoBrowsePage(query: _query),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = MonoTokens.of(context);
    final media = MediaQuery.of(context);
    final barBottom = 28 + media.padding.bottom;
    final keyboard = media.viewInsets.bottom;
    return Scaffold(
      backgroundColor: t.bg,
      // The bar stays where it is; only the search rides up on the keyboard.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          for (final index in _opened)
            Positioned.fill(
              key: ValueKey(index),
              child: Offstage(
                offstage: index != _index,
                child: TickerMode(
                  enabled: index == _index,
                  child: _page(index),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: barBottom,
            child: Center(
              child: MonoFloatingBar(
                tabs: [
                  MonoTab(
                    const Icon(Icons.insights_rounded),
                    l10n.monoInsights,
                  ),
                  MonoTab(const MonoLongevityIcon(), l10n.monoLongevity),
                  MonoTab(const Icon(Icons.grid_view_rounded), l10n.monoBrowse),
                ],
                selected: _index,
                onSelected: _open,
                addLabel: l10n.monoAdd,
                onAdd: () => showMonoAddMenu(context, bottom: barBottom),
              ),
            ),
          ),
          if (_index == _browse)
            Positioned(
              left: (media.size.width - MonoFloatingBar.width) / 2,
              right: (media.size.width - MonoFloatingBar.width) / 2,
              bottom: keyboard > 0
                  ? keyboard + 12
                  : barBottom + MonoFloatingBar.height + 14,
              child: MonoSearchPill(
                query: _query,
                hint: l10n.monoSearch,
                clearLabel: l10n.close,
              ),
            ),
        ],
      ),
    );
  }
}
