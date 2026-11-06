import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/formatters.dart';
import '../../app/morning_notices.dart';
import '../../data/settings_controller.dart';
import '../../widgets/fold_section.dart';

/// The switches that make the notifications live messages: they stay on top
/// until they are swiped away or the app is opened. All of them are off
/// until the user turns them on.
class LiveSettings extends StatefulWidget {
  const LiveSettings({required this.settings, super.key});

  final SettingsController settings;

  @override
  State<LiveSettings> createState() => _LiveSettingsState();
}

class _LiveSettingsState extends State<LiveSettings>
    with WidgetsBindingObserver {
  // Whether Android lets Pulse highlight live messages; null while asked.
  bool? _promotable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ask();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The setting is changed outside the app, so ask again on the way back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ask();
  }

  Future<void> _ask() async {
    final value = await MorningNotices.promotable();
    if (mounted) setState(() => _promotable = value);
  }

  Widget _row(String text, bool value, void Function(bool) set) {
    return SettingSwitch(
      title: text,
      value: value,
      onChanged: (on) {
        set(on);
        // A notification needs the system's consent.
        if (on) MorningNotices.allow();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = Formats.of(context).l10n;
    final settings = widget.settings;
    final muted = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(l10n.liveMorning, settings.liveMorning, settings.setLiveMorning),
          _row(
            l10n.liveSupplements,
            settings.liveSupplements,
            settings.setLiveSupplements,
          ),
          _row(l10n.liveWeek, settings.liveWeek, settings.setLiveWeek),
          _row(l10n.liveDay, settings.liveDay, settings.setLiveDay),
          SettingBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.liveNote, style: muted),
                if (_promotable == false) ...[
                  const SizedBox(height: 8),
                  Text(l10n.liveSystemOff, style: muted),
                  const SizedBox(height: 8),
                  M3EFilledButton.tonal(
                    onPressed: MorningNotices.openPromotionSettings,
                    child: Text(l10n.liveSystemOpen),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
