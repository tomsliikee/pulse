import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../looks/insights_mono/theme/mono_tokens.dart';
import '../looks/insights_mono/theme/mono_type.dart';
import '../looks/insights_mono/widgets/mono_motion.dart';
import '../theme/pulse_look.dart';

/// A filled button: the expressive one of the standard look, or in the
/// Insights looks a capsule of solid ink (the tonal kind in fill) that
/// squashes while pressed, without a ripple.
class LookButton extends StatelessWidget {
  const LookButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.size = M3EButtonSize.sm,
    this.enabled = true,
  }) : tonal = false;

  const LookButton.tonal({
    super.key,
    required this.onPressed,
    required this.child,
    this.size = M3EButtonSize.sm,
    this.enabled = true,
  }) : tonal = true;

  final VoidCallback? onPressed;
  final Widget child;
  final M3EButtonSize size;
  final bool enabled;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    if (!PulseLook.monoOf(context)) {
      return tonal
          ? M3EFilledButton.tonal(
              size: size,
              enabled: enabled,
              onPressed: onPressed,
              child: child,
            )
          : M3EFilledButton(
              size: size,
              enabled: enabled,
              onPressed: onPressed,
              child: child,
            );
    }
    final t = MonoTokens.of(context);
    final active = enabled && onPressed != null;
    final ink = tonal ? t.ink : t.onSolid;
    final height = switch (size) {
      M3EButtonSize.xs => 36.0,
      M3EButtonSize.sm => 44.0,
      _ => 52.0,
    };
    return Semantics(
      button: true,
      enabled: active,
      child: MonoPress(
        onTap: active ? onPressed : null,
        squash: 0.04,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: active ? 1 : 0.4,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tonal ? t.fill : t.solid,
              borderRadius: BorderRadius.circular(height / 2),
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: ink, size: 20),
              child: DefaultTextStyle.merge(
                style: MonoType.inter(15, 20, FontWeight.w600, ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
