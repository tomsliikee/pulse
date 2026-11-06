import 'package:material_ui/material_ui.dart';

import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import 'mono_category.dart';
import 'mono_motion.dart';

/// A card of the look: category and time on top, the statement in serif, then
/// one number and one small chart. Tapping it opens the category.
class MonoCard extends StatelessWidget {
  const MonoCard({
    super.key,
    required this.category,
    required this.categoryLabel,
    this.statement,
    this.time,
    this.onTap,
    this.child,
    this.semanticsLabel,
    this.background,
    this.icon,
  });

  final MonoCategory category;

  /// In place of the category's own icon.
  final IconData? icon;
  final String categoryLabel;
  final String? statement;
  final String? time;
  final VoidCallback? onTap;
  final Widget? child;

  /// One sentence for the screen reader that says what the card shows.
  final String? semanticsLabel;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final color = category.color(t);
    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: background ?? t.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon ?? category.icon, size: 18, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  categoryLabel,
                  style: MonoType.category(color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (time != null) ...[
                Text(time!, style: MonoType.time(t)),
                const SizedBox(width: 2),
              ],
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: 20, color: t.ink3),
            ],
          ),
          if (statement != null) ...[
            const SizedBox(height: 12),
            Text(statement!, style: MonoType.statement(t)),
          ],
          if (child != null) ...[const SizedBox(height: 18), child!],
        ],
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      label:
          semanticsLabel ??
          '$categoryLabel${statement == null ? '' : ', $statement'}',
      child: ExcludeSemantics(
        excluding: semanticsLabel != null,
        child: MonoPress(onTap: onTap, child: body),
      ),
    );
  }
}

/// A plain card without header, for lists and notes.
class MonoSurface extends StatelessWidget {
  const MonoSurface({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 20),
    this.onTap,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
    return onTap == null ? body : MonoPress(onTap: onTap, child: body);
  }
}

/// A number with its unit and a label above it.
class MonoStat extends StatelessWidget {
  const MonoStat({
    super.key,
    required this.value,
    this.unit,
    this.label,
    this.small = false,
    this.color,
  });

  final String value;
  final String? unit;
  final String? label;
  final bool small;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final style = small ? MonoType.numberSmall(t) : MonoType.number(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: MonoType.label(t)),
          const SizedBox(height: 4),
        ],
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: color == null ? style : style.copyWith(color: color),
              ),
              if (unit != null && unit!.isNotEmpty)
                TextSpan(text: ' $unit', style: MonoType.unit(t)),
            ],
          ),
        ),
      ],
    );
  }
}
