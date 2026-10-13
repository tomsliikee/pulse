import 'dart:async';

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/health_controller.dart';
import '../../theme/page_accent.dart';
import '../morning/morning_sunrise.dart';
import '../profile/language_sheet.dart';
import 'intro_cards.dart';

/// The first start: a few cards to swipe through that say what Pulse reads
/// and where it stays, ask the system for it, and set up who the numbers
/// are about. Every card can be passed and the whole can be skipped.
class IntroPage extends StatefulWidget {
  const IntroPage({super.key, this.again = false});

  /// Whether it was opened from the profile to be seen once more. It is
  /// then a route that closes, and ends without the sunrise.
  final bool again;

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  static const _cards = <Widget>[
    WelcomeCard(),
    PrivacyCard(),
    AccessCard(),
    OptionalCard(),
    AboutCard(),
    IntroGoalsCard(),
    ModeCard(),
  ];

  /// The longest the sunrise waits for the first read.
  static const Duration _waitsAtMost = Duration(seconds: 15);

  final PageController _pages = PageController();
  int _index = 0;

  /// Whether the cards are done and the sun rises over the first read.
  bool _leaving = false;
  bool _ended = false;
  Timer? _patience;
  HealthController? _awaited;

  @override
  void dispose() {
    _patience?.cancel();
    _awaited?.removeListener(_endWhenRead);
    _pages.dispose();
    super.dispose();
  }

  void _turn(int by) => _pages.animateToPage(
    _index + by,
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeInOutCubicEmphasized,
  );

  /// Leaves the cards: [skipped] at once, else behind the sunrise where
  /// there is something to read.
  void _finish({bool skipped = false}) {
    if (widget.again) {
      // Not asked whether it may: back would turn a card instead.
      Navigator.of(context).pop();
      return;
    }
    final health = AppScope.of(context).health;
    if (skipped || health.status != HealthStatus.ready) {
      _end();
      return;
    }
    setState(() => _leaving = true);
    _patience = Timer(_waitsAtMost, _end);
  }

  void _risen() {
    final health = AppScope.of(context).health;
    if (!health.refreshing) {
      _end();
      return;
    }
    _awaited = health..addListener(_endWhenRead);
  }

  void _endWhenRead() {
    if (_awaited?.refreshing ?? false) return;
    _end();
  }

  void _end() {
    if (_ended || !mounted) return;
    _ended = true;
    final AppScope(:health, :settings) = AppScope.of(context);
    // What no switch asked for is not asked for behind the user's back.
    if (!health.historyAccess) unawaited(health.leaveHistory());
    settings.setIntroDone(true);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      // Back turns to the card before; on the first it leaves.
      canPop: _index == 0 || _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _turn(-1);
      },
      child: PageAccent.day(
        child: Scaffold(
          backgroundColor: scheme.surfaceContainer,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _leaving
                ? ListenableBuilder(
                    key: const ValueKey('sunrise'),
                    listenable: scope.health,
                    builder: (context, _) {
                      final l10n = Formats.of(context).l10n;
                      return MorningSunrise(
                        name: scope.settings.name,
                        greeting: switch (scope.settings.name) {
                          final name? => l10n.introHello(name),
                          null => l10n.introHelloPlain,
                        },
                        syncing: scope.health.refreshing,
                        syncingLabel: l10n.introLoading,
                        onRisen: _risen,
                      );
                    },
                  )
                : SafeArea(
                    key: const ValueKey('cards'),
                    child: _build(context),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = Formats.of(context).l10n;
    final last = _index == _cards.length - 1;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  spacing: 6,
                  children: [
                    for (var i = 0; i < _cards.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        width: i == _index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? scheme.primary
                              : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
              if (_index == 0)
                IconButton(
                  onPressed: () => showLanguageSheet(context),
                  tooltip: l10n.language,
                  icon: const Icon(Icons.language_rounded),
                ),
              if (widget.again)
                IconButton(
                  onPressed: _finish,
                  tooltip: l10n.close,
                  icon: const Icon(Icons.close_rounded),
                )
              else
                TextButton(
                  onPressed: () => _finish(skipped: true),
                  child: Text(l10n.introSkip),
                ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pages,
            onPageChanged: (index) {
              Haptics.selection();
              setState(() => _index = index);
            },
            children: _cards,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: M3EFilledButton(
              size: M3EButtonSize.md,
              onPressed: last ? _finish : () => _turn(1),
              child: Text(last ? l10n.introFinish : l10n.morningNext),
            ),
          ),
        ),
      ],
    );
  }
}
