import 'package:material_ui/material_ui.dart';

import '../../../app/haptics.dart';
import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import 'mono_category.dart';
import 'mono_floating_bar.dart';
import 'mono_motion.dart';

/// The page frame of the look: the ground, a gutter of 16 px and room at the
/// bottom for the floating bar where there is one. The content runs under
/// the clear status bar and fades out beneath it.
class MonoPage extends StatefulWidget {
  const MonoPage({
    super.key,
    required this.children,
    this.top,
    this.topInset = 16,
    this.bottomInset = 40,
    this.controller,
    this.floatTitle,
    this.floatActions = const [],
  });

  final List<Widget> children;

  /// What sits above the content, such as the back pill.
  final Widget? top;

  /// Air between the status bar and the first child.
  final double topInset;
  final double bottomInset;
  final ScrollController? controller;

  /// The title of a page whose header scrolls away. While the page is
  /// scrolled down a glass pill with it and [floatActions] floats in its
  /// place; a tap on the pill scrolls back to the top.
  final String? floatTitle;
  final List<Widget> floatActions;

  /// How far the page is scrolled before the pill appears.
  static const double floatAfter = 72;

  @override
  State<MonoPage> createState() => _MonoPageState();
}

class _MonoPageState extends State<MonoPage> {
  ScrollController? _own;
  final _floating = ValueNotifier<bool>(false);

  ScrollController get _scroll =>
      widget.controller ?? (_own ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(MonoPage old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _own)?.removeListener(_onScroll);
      _scroll.addListener(_onScroll);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    _floating.value = _scroll.offset > MonoPage.floatAfter;
  }

  void _toTop() {
    Haptics.tap();
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: monoStill(context)
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _own?.dispose();
    _floating.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final padding = MediaQuery.paddingOf(context);
    final title = widget.floatTitle;
    return ColoredBox(
      color: t.bg,
      child: Stack(
        children: [
          ListView(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(
              16,
              padding.top + widget.topInset,
              16,
              widget.bottomInset + padding.bottom,
            ),
            children: [?widget.top, ...widget.children],
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: padding.top + 10,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      t.bg.withValues(alpha: 0.82),
                      t.bg.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (title != null)
            Positioned(
              left: 16,
              right: 16,
              top: padding.top + 8,
              child: ValueListenableBuilder<bool>(
                valueListenable: _floating,
                builder: (context, floating, child) {
                  final still = monoStill(context);
                  return IgnorePointer(
                    ignoring: !floating,
                    child: AnimatedSlide(
                      duration: still
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      offset: floating ? Offset.zero : const Offset(0, -0.4),
                      child: AnimatedOpacity(
                        duration: still
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        opacity: floating ? 1 : 0,
                        child: child,
                      ),
                    ),
                  );
                },
                child: _FloatingHeader(
                  title: title,
                  actions: widget.floatActions,
                  onTap: _toTop,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The header of a page once it is scrolled: its title in a pill on the
/// left, like the back pill of a sub page, and its icons in a pill on the
/// right. A tap on the title scrolls the page back to the top.
class _FloatingHeader extends StatelessWidget {
  const _FloatingHeader({
    required this.title,
    required this.actions,
    required this.onTap,
  });

  final String title;
  final List<Widget> actions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              button: true,
              label: title,
              child: ExcludeSemantics(
                child: MonoPress(
                  onTap: onTap,
                  child: MonoGlass(
                    radius: 22,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MonoType.inter(14, 19, FontWeight.w600, t.ink),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (actions.isNotEmpty)
          MonoGlass(
            radius: 22,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, a) in actions.indexed) ...[
                    if (i > 0) const SizedBox(width: 4),
                    a,
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The page of a category or a detail: the category and its statement as
/// the title, then [children]. The back pill with the name of the page
/// floats over it and stays while the page scrolls.
class MonoSubPage extends StatelessWidget {
  const MonoSubPage({
    super.key,
    required this.category,
    required this.categoryLabel,
    required this.backLabel,
    required this.children,
    this.statement,
    this.trailing,
    this.icon,
    this.kicker,
  });

  final MonoCategory category;

  /// The name of the page, in the back pill and above the statement.
  final String categoryLabel;

  /// In place of the category's own icon.
  final IconData? icon;

  /// A word above the statement in place of [categoryLabel], such as a date.
  final String? kicker;

  /// The page that is gone back to, for the screen reader.
  final String backLabel;
  final String? statement;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final color = category.color(t);
    return Scaffold(
      backgroundColor: t.bg,
      body: MonoFloatingBack(
        title: categoryLabel,
        backLabel: backLabel,
        color: color,
        trailing: trailing,
        child: MonoPage(
          topInset: MonoFloatingBack.room,
          children: [
            Row(
              children: [
                Icon(icon ?? category.icon, size: 18, color: color),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    kicker ?? categoryLabel,
                    style: MonoType.category(color),
                  ),
                ),
              ],
            ),
            if (statement != null) ...[
              const SizedBox(height: 10),
              MonoSerif(statement!, spec: const (32, 38, -0.02, 1.1)),
            ],
            const SizedBox(height: 28),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 22),
              MonoRise(order: i, page: categoryLabel, child: children[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// [child] with the back pill floating over its top, below the status bar.
class MonoFloatingBack extends StatelessWidget {
  const MonoFloatingBack({
    super.key,
    required this.title,
    required this.child,
    this.backLabel,
    this.color,
    this.trailing,
  });

  /// The space a page leaves above its content for the pill.
  static const double room = 14 + 44 + 22;

  final String title;
  final String? backLabel;
  final Color? color;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        child,
        Positioned(
          left: 16,
          right: 16,
          top: top + 14,
          child: Row(
            children: [
              Flexible(
                child: MonoBackPill(
                  label: title,
                  backLabel: backLabel,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              const Spacer(),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }
}

/// "‹ Sleep": back, with the name of the page, on the glass of the bar.
class MonoBackPill extends StatelessWidget {
  const MonoBackPill({
    super.key,
    required this.label,
    this.backLabel,
    this.color,
  });

  final String label;
  final String? backLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final c = color ?? t.ink;
    return Semantics(
      button: true,
      label: backLabel ?? MaterialLocalizations.of(context).backButtonTooltip,
      child: ExcludeSemantics(
        child: MonoPress(
          onTap: () {
            Haptics.tap();
            Navigator.of(context).maybePop();
          },
          child: MonoGlass(
            radius: 22,
            child: Container(
              height: 44,
              padding: const EdgeInsets.only(left: 8, right: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_left_rounded, size: 26, color: c),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MonoType.inter(15, 20, FontWeight.w600, t.ink),
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

/// The heading of a section on a page.
class MonoSection extends StatelessWidget {
  const MonoSection(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Expanded(child: MonoSerif.heading(title)),
          ?trailing,
        ],
      ),
    );
  }
}

/// A row of a list, without a divider; air separates it from the next.
class MonoRow extends StatelessWidget {
  const MonoRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.unit,
    this.when,
    this.leading,
    this.onTap,
    this.chevron = true,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final String? unit;
  final String? when;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MonoType.inter(16, 22, FontWeight.w500, t.ink),
                ),
                if (subtitle != null) Text(subtitle!, style: MonoType.label(t)),
              ],
            ),
          ),
          if (value != null)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: MonoType.inter(16, 22, FontWeight.w600, t.ink),
                  ),
                  if (unit != null && unit!.isNotEmpty)
                    TextSpan(text: ' $unit', style: MonoType.unit(t)),
                ],
              ),
            ),
          if (when != null) ...[
            const SizedBox(width: 10),
            Text(when!, style: MonoType.time(t)),
          ],
          if (onTap != null && chevron)
            Icon(Icons.chevron_right_rounded, size: 20, color: t.ink3),
        ],
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      child: onTap == null
          ? row
          : MonoPress(onTap: onTap, squash: 0.012, child: row),
    );
  }
}
