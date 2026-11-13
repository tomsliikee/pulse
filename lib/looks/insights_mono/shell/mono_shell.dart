import 'package:material_ui/material_ui.dart';

import '../pages/insights_page.dart';
import '../pages/longevity_page.dart';
import '../pages/training/training_page.dart';
import '../theme/mono_tokens.dart';
import 'mono_dock_controller.dart';

/// The home of the look: three pages — Insights, Training and Longevity.
/// The dock with the search, the tabs and the + floats above it and every
/// page pushed on it; it lives above the navigator, see `MonoDockHost`.
class MonoShell extends StatefulWidget {
  const MonoShell({super.key});

  @override
  State<MonoShell> createState() => _MonoShellState();
}

class _MonoShellState extends State<MonoShell> {
  final Set<int> _opened = {0};
  MonoDockController? _dock;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dock = MonoDockScope.read(context);
    if (dock != _dock) {
      _dock?.removeListener(_changed);
      _dock?.detachHome();
      _dock = dock;
      dock?.addListener(_changed);
      // A shell made anew, as after a change of look, opens the tab the dock
      // shows.
      if (dock != null && dock.tab != _index) {
        _index = dock.tab;
        _opened.add(_index);
      }
      // Not during the build: attaching notifies the dock.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _dock == dock) dock?.attachHome();
      });
    }
  }

  int _index = 0;

  void _changed() {
    final tab = _dock?.tab ?? 0;
    if (tab == _index) return;
    // The keyboard of the search does not follow to another page.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _index = tab;
      _opened.add(tab);
    });
  }

  @override
  void dispose() {
    _dock?.removeListener(_changed);
    _dock?.detachHome();
    super.dispose();
  }

  /// The pages are built once: the same widget again lets the framework skip
  /// them, so the keyboard sliding in does not rebuild every page per frame.
  final Map<int, Widget> _pages = {};

  Widget _page(int index) => _pages.putIfAbsent(
    index,
    () => switch (index) {
      0 => const MonoInsightsPage(),
      1 => const MonoTrainingPage(),
      _ => const MonoLongevityPage(),
    },
  );

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      // The dock rides the keyboard by itself; the pages stay where they are.
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
        ],
      ),
    );
  }
}
