import 'package:material_ui/material_ui.dart';

import '../../../app/haptics.dart';
import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import 'mono_floating_bar.dart';
import 'mono_motion.dart';

/// Opens [builder] as a sheet of the look: glass that rises from the bottom
/// edge, a grabber, and room for the keyboard. Swiped down or tapped beside,
/// it closes.
Future<T?> showMonoSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.2),
    showDragHandle: false,
    builder: (context) => MonoSheet(title: title, child: builder(context)),
  );
}

/// The frame of a sheet: glass with round top corners, a grabber, a
/// heading in the serif, and [child] above the keyboard.
class MonoSheet extends StatelessWidget {
  const MonoSheet({super.key, required this.child, this.title});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, keyboard + 8 + bottom),
      child: MonoGlass(
        radius: 30,
        shadow: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86 - keyboard,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(
                    color: t.ink3.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 2),
                  child: Text(
                    title!,
                    style: MonoType.inter(22, 28, FontWeight.w600, t.ink),
                  ),
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The main action of a sheet or a card: a solid capsule across the width.
class MonoPrimaryButton extends StatelessWidget {
  const MonoPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tonal = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// The quieter kind: fill instead of solid ink.
  final bool tonal;

  /// For removing: the colour of the heart.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final enabled = onTap != null;
    final fill = danger
        ? t.heartBg
        : tonal
        ? t.fill
        : t.solid;
    final ink = danger
        ? t.heart
        : tonal
        ? t.ink
        : t.onSolid;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: MonoPress(
          onTap: enabled
              ? () {
                  Haptics.tap();
                  onTap!();
                }
              : null,
          squash: 0.03,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: ink),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MonoType.inter(16, 22, FontWeight.w600, ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A text field of the look: a soft fill, no line, the label above.
class MonoField extends StatelessWidget {
  const MonoField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.suffix,
    this.keyboardType,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.textAlign = TextAlign.start,
    this.focusNode,
    this.dense = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? suffix;
  final TextInputType? keyboardType;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextAlign textAlign;
  final FocusNode? focusNode;

  /// The small kind, for numbers in a row.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final field = Container(
      height: dense ? 44 : 52,
      padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(dense ? 14 : 18),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        keyboardType: keyboardType,
        textAlign: textAlign,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        cursorColor: t.ink,
        style: MonoType.inter(
          dense ? 16 : 17,
          22,
          dense ? FontWeight.w600 : FontWeight.w500,
          t.ink,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          filled: false,
          isCollapsed: true,
          hintText: hint,
          hintStyle: MonoType.inter(
            dense ? 16 : 17,
            22,
            FontWeight.w400,
            t.ink3,
          ),
          suffixText: suffix,
          suffixStyle: MonoType.unit(t),
        ),
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label!, style: MonoType.label(t)),
        ),
        field,
      ],
    );
  }
}

/// A row of a sheet that is a choice: icon, text, a check when chosen.
class MonoChoiceRow extends StatelessWidget {
  const MonoChoiceRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.chosen = false,
    this.trailing,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool chosen;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Semantics(
      button: true,
      selected: chosen,
      child: MonoPress(
        onTap: () {
          Haptics.tap();
          onTap();
        },
        squash: 0.015,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: chosen ? t.solid : t.fill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: chosen ? t.onSolid : t.ink),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: MonoType.inter(
                        16,
                        21,
                        FontWeight.w600,
                        chosen ? t.onSolid : t.ink,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: MonoType.inter(
                          13,
                          18,
                          FontWeight.w400,
                          chosen ? t.onSolid.withValues(alpha: 0.75) : t.ink2,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
              if (chosen && trailing == null)
                Icon(Icons.check_rounded, size: 20, color: t.onSolid),
            ],
          ),
        ),
      ),
    );
  }
}
