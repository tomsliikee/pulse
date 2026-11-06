import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../app/haptics.dart';
import '../looks/insights_mono/widgets/mono_controls.dart';
import '../theme/pulse_look.dart';

/// A choice of a few: a connected group of tonal buttons, or in the Insights
/// looks their slider, whose thumb can be dragged.
class LookToggle extends StatelessWidget {
  const LookToggle({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.size = M3EButtonSize.sm,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final M3EButtonSize size;

  @override
  Widget build(BuildContext context) {
    if (PulseLook.monoOf(context)) {
      return MonoSegmented(
        labels: labels,
        selected: selected,
        onChanged: onChanged,
      );
    }
    return M3EToggleButtonGroup(
      type: M3EButtonGroupType.connected,
      style: M3EButtonStyle.tonal,
      size: size,
      haptic: Haptics.widget,
      selectedIndex: selected,
      onSelectedIndexChanged: (index) {
        if (index != null) onChanged(index);
      },
      actions: [
        for (final label in labels)
          M3EToggleButtonGroupAction(label: Text(label)),
      ],
    );
  }
}
