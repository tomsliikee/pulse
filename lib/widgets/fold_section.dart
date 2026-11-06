import 'package:material_ui/material_ui.dart';

import '../app/haptics.dart';
import '../theme/app_type.dart';
import '../theme/pulse_look.dart';

/// A part of the settings in a card that folds open: its icon, its title
/// and, while folded, a line that says how it is set. [FoldSection.inner]
/// is a fold inside one, a row without card or icon.
class FoldSection extends StatefulWidget {
  const FoldSection({
    super.key,
    required IconData this.icon,
    required this.title,
    required this.children,
    this.summary,
    this.initiallyOpen = false,
  });

  const FoldSection.inner({
    super.key,
    required this.title,
    required this.children,
    this.summary,
    this.initiallyOpen = false,
  }) : icon = null;

  final IconData? icon;
  final String title;

  /// How it is set, in one line; shown while folded.
  final String? summary;
  final List<Widget> children;
  final bool initiallyOpen;

  @override
  State<FoldSection> createState() => FoldSectionState();
}

class FoldSectionState extends State<FoldSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: widget.initiallyOpen ? 1 : 0,
  );
  @override
  void initState() {
    super.initState();
    // The summary is left out while open, and back once folding starts.
    _open.addStatusListener((_) {
      if (mounted) setState(() {});
    });
  }

  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _open,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  bool get isOpen => _open.status.isForwardOrCompleted;

  /// Folds it open without a tap, as a test that is after what is inside.
  @visibleForTesting
  void open() => setState(() => _open.value = 1);

  void _toggle() {
    Haptics.selection();
    if (MediaQuery.disableAnimationsOf(context)) {
      _open.value = isOpen ? 0 : 1;
    } else if (isOpen) {
      _open.reverse();
    } else {
      _open.forward();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _curve.dispose();
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = PulseLook.monoOf(context);
    final icon = widget.icon;
    final head = Semantics(
      button: true,
      expanded: isOpen,
      child: InkWell(
        onTap: _toggle,
        child: Padding(
          padding: icon == null
              ? const EdgeInsets.fromLTRB(20, 14, 16, 14)
              : const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: mono ? scheme.primary : scheme.primaryContainer,
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: mono ? scheme.onPrimary : scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: icon == null
                          ? theme.textTheme.titleMedium
                          : AppType.of(context).heading(
                              theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    if (widget.summary case final summary?
                        when summary.isNotEmpty && _open.value < 1)
                      SizeTransition(
                        sizeFactor: ReverseAnimation(_curve),
                        alignment: AlignmentDirectional.topStart,
                        child: FadeTransition(
                          opacity: ReverseAnimation(_curve),
                          child: Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              RotationTransition(
                turns: Tween(begin: 0.0, end: 0.5).animate(_curve),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final body = SizeTransition(
      sizeFactor: _curve,
      alignment: AlignmentDirectional.topStart,
      child: Padding(
        padding: icon == null
            ? const EdgeInsets.only(left: 16)
            : const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: widget.children,
        ),
      ),
    );
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [head, body],
    );
    if (icon == null) return column;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surfaceBright,
        borderRadius: BorderRadius.circular(mono ? 22 : 28),
        clipBehavior: Clip.antiAlias,
        child: column,
      ),
    );
  }
}

/// A switch with its title and note. What hangs on it opens beneath while
/// it is on, indented.
class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.note,
    this.children = const [],
  });

  final String title;
  final String? note;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Shown only while [value] is on.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = MergeSemantics(
      child: InkWell(
        onTap: onChanged == null ? null : () => _set(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          note!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(value: value, onChanged: onChanged == null ? null : _set),
            ],
          ),
        ),
      ),
    );
    if (children.isEmpty) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: AlignmentDirectional.topStart,
          child: value
              ? Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  void _set(bool on) {
    // After the change, so switching the haptics off is silent and
    // switching them on is felt.
    onChanged!(on);
    Haptics.selection();
  }
}

/// A row that opens a sheet or a page: its label, and how it is set.
class SettingLink extends StatelessWidget {
  const SettingLink({
    super.key,
    required this.title,
    required this.onTap,
    this.value,
    this.subtitle,
  });

  final String title;
  final String? value;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 12),
              // A long name or place gives way to its label.
              Flexible(
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: PulseLook.monoOf(context)
                        ? scheme.onSurfaceVariant
                        : scheme.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// A note or a choice inside a [FoldSection], with the section's gutter.
class SettingBlock extends StatelessWidget {
  const SettingBlock({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 8), child: child);
}
