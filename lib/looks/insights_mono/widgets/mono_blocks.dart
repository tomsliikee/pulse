import 'package:material_ui/material_ui.dart';

import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import 'mono_card.dart';
import 'mono_page.dart';

/// Rows on one card, with air between them instead of lines.
class MonoList extends StatelessWidget {
  const MonoList({super.key, required this.children, this.gap = 14});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => MonoSurface(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    ),
  );
}

/// A section: its serif heading and what belongs under it.
class MonoBlock extends StatelessWidget {
  const MonoBlock({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 14),
      MonoSection(title, trailing: trailing),
      const SizedBox(height: 14),
      child,
    ],
  );
}

/// A quiet sentence below a card.
class MonoNote extends StatelessWidget {
  const MonoNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(text, style: MonoType.time(MonoTokens.of(context))),
  );
}

/// Labels spread along the foot of a chart.
class MonoAxis extends StatelessWidget {
  const MonoAxis(this.labels, {super.key});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (final label in labels)
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: MonoType.inter(11, 14, FontWeight.w500, t.ink3),
              ),
            ),
        ],
      ),
    );
  }
}

/// A label with a value at its end, for numbers in a list.
class MonoPair extends StatelessWidget {
  const MonoPair({
    super.key,
    required this.label,
    required this.value,
    this.dot,
    this.sub,
  });

  final String label;
  final String value;
  final Color? dot;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Row(
      children: [
        if (dot != null) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: MonoType.body(t)),
              if (sub != null) Text(sub!, style: MonoType.label(t)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(value, style: MonoType.inter(15, 21, FontWeight.w600, t.ink)),
      ],
    );
  }
}

/// A round icon button in the fill of the look.
class MonoIconButton extends StatelessWidget {
  const MonoIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.fill,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: onTap == null ? t.ink3 : t.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A difference such as "+3 bpm": in the colour of years gained where it is
/// good, of years lost where it is not, in grey where it is neither.
class MonoDelta extends StatelessWidget {
  const MonoDelta(this.text, {super.key, this.good});

  final String text;
  final bool? good;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final color = switch (good) {
      true => t.up,
      false => t.down,
      null => t.ink2,
    };
    return Text(
      text,
      textAlign: TextAlign.end,
      style: MonoType.inter(14, 18, FontWeight.w600, color),
    );
  }
}

/// Numbers two to a row, each with its label above.
class MonoGrid extends StatelessWidget {
  const MonoGrid({super.key, required this.cells});

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) => MonoSurface(
    child: Column(
      children: [
        for (var i = 0; i < cells.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cells[i]),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < cells.length
                    ? cells[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

/// Sentences of advice, each with the same small icon.
class MonoSentences extends StatelessWidget {
  const MonoSentences({
    super.key,
    required this.icon,
    required this.sentences,
    this.note,
  });

  final IconData icon;
  final List<String> sentences;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return MonoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sentences.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.fill,
                  ),
                  child: Icon(icon, size: 18, color: t.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(sentences[i], style: MonoType.body(t)),
                  ),
                ),
              ],
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 14),
            Text(note!, style: MonoType.time(t)),
          ],
        ],
      ),
    );
  }
}
