import 'package:material_ui/material_ui.dart';

import '../../../../app/haptics.dart';
import '../../../../data/training/training_models.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../theme/mono_tokens.dart';
import '../../theme/mono_type.dart';
import '../../widgets/mono_motion.dart';
import 'training_text.dart';

/// Where a muscle is drawn on a figure 100 wide and 210 tall, as ovals:
/// (centre x, centre y, half width, half height). Mirrored muscles come in
/// pairs.
const Map<Muscle, List<(double, double, double, double)>> _front = {
  Muscle.shoulders: [(27, 47, 8, 7), (73, 47, 8, 7)],
  Muscle.chest: [(41, 56, 10, 8), (59, 56, 10, 8)],
  Muscle.biceps: [(22, 66, 5, 10), (78, 66, 5, 10)],
  Muscle.forearms: [(18, 89, 4.5, 11), (82, 89, 4.5, 11)],
  Muscle.abs: [(50, 82, 8, 15)],
  Muscle.obliques: [(37, 84, 4, 11), (63, 84, 4, 11)],
  Muscle.adductors: [(45, 123, 4, 11), (55, 123, 4, 11)],
  Muscle.quads: [(38, 132, 7.5, 19), (62, 132, 7.5, 19)],
  Muscle.calves: [(38, 172, 5, 14), (62, 172, 5, 14)],
};

const Map<Muscle, List<(double, double, double, double)>> _back = {
  Muscle.traps: [(50, 44, 13, 6)],
  Muscle.shoulders: [(27, 48, 8, 7), (73, 48, 8, 7)],
  Muscle.upperBack: [(50, 58, 12, 7)],
  Muscle.lats: [(38, 72, 7, 12), (62, 72, 7, 12)],
  Muscle.triceps: [(22, 66, 5, 10), (78, 66, 5, 10)],
  Muscle.forearms: [(18, 89, 4.5, 11), (82, 89, 4.5, 11)],
  Muscle.lowerBack: [(50, 90, 8, 8)],
  Muscle.glutes: [(42, 108, 8.5, 8), (58, 108, 8.5, 8)],
  Muscle.hamstrings: [(39, 135, 7, 17), (61, 135, 7, 17)],
  Muscle.calves: [(38, 172, 5.5, 14), (62, 172, 5.5, 14)],
};

/// The sets of the last seven days on two figures, front and back: the
/// more sets a muscle got, the stronger its colour. A tap names the muscle.
class MuscleMap extends StatefulWidget {
  const MuscleMap({super.key, required this.sets, required this.semantics});

  final Map<Muscle, double> sets;
  final String semantics;

  /// The sets of a week at which a muscle shows in full colour.
  static const double full = 12;

  @override
  State<MuscleMap> createState() => _MuscleMapState();
}

class _MuscleMapState extends State<MuscleMap> {
  Muscle? _chosen;

  Muscle? _hit(Offset at, Size size, bool front) {
    final scale = size.height / 210;
    final dx = (size.width - 100 * scale) / 2;
    final p = Offset((at.dx - dx) / scale, at.dy / scale);
    final map = front ? _front : _back;
    Muscle? best;
    var bestD = double.infinity;
    for (final MapEntry(key: m, value: ovals) in map.entries) {
      for (final (x, y, w, h) in ovals) {
        final nx = (p.dx - x) / (w + 3);
        final ny = (p.dy - y) / (h + 3);
        final d = nx * nx + ny * ny;
        if (d < 1 && d < bestD) {
          best = m;
          bestD = d;
        }
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    Widget figure(bool front) => Expanded(
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, 210 * 1.1);
          return GestureDetector(
            onTapUp: (d) {
              final m = _hit(d.localPosition, size, front);
              Haptics.selection();
              setState(() => _chosen = m == _chosen ? null : m);
            },
            child: MonoDrawIn(
              builder: (context, p) => CustomPaint(
                size: size,
                painter: _FigurePainter(
                  ovals: front ? _front : _back,
                  sets: widget.sets,
                  body: t.fill,
                  color: t.recovery,
                  chosen: _chosen,
                  ink: t.ink,
                  t: p,
                ),
              ),
            ),
          );
        },
      ),
    );
    return Semantics(
      label: widget.semantics,
      image: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                figure(true),
                const SizedBox(width: 12),
                figure(false),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _Legend(chosen: _chosen, sets: widget.sets, tokens: t),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.chosen,
    required this.sets,
    required this.tokens,
  });

  final Muscle? chosen;
  final Map<Muscle, double> sets;
  final MonoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final l10n = AppLocalizations.of(context);
    final m = chosen;
    if (m == null) {
      return Text(
        l10n.trainingMapHint,
        textAlign: TextAlign.center,
        style: MonoType.label(t),
      );
    }
    final n = sets[m] ?? 0;
    final shown = n == n.roundToDouble()
        ? '${n.round()}'
        : n.toStringAsFixed(1);
    return Text(
      '${muscleLabel(l10n, m)} · ${l10n.trainingSetsWeek(shown)}',
      textAlign: TextAlign.center,
      style: MonoType.inter(14, 18, FontWeight.w600, t.ink),
    );
  }
}

class _FigurePainter extends CustomPainter {
  const _FigurePainter({
    required this.ovals,
    required this.sets,
    required this.body,
    required this.color,
    required this.chosen,
    required this.ink,
    required this.t,
  });

  final Map<Muscle, List<(double, double, double, double)>> ovals;
  final Map<Muscle, double> sets;
  final Color body;
  final Color color;
  final Color ink;
  final Muscle? chosen;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / 210;
    canvas.save();
    canvas.translate((size.width - 100 * scale) / 2, 0);
    canvas.scale(scale);
    final fill = Paint()..color = body;
    // The figure: head, neck, trunk, arms and legs as soft shapes.
    canvas.drawCircle(const Offset(50, 18), 12, fill);
    canvas.drawRRect(
      RRect.fromLTRBR(45, 28, 55, 40, const Radius.circular(4)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(28, 38, 72, 104, const Radius.circular(16)),
      fill,
    );
    for (final x in const [14.0, 77.0]) {
      canvas.drawRRect(
        RRect.fromLTRBR(x, 42, x + 9, 102, const Radius.circular(5)),
        fill,
      );
    }
    canvas.drawRRect(
      RRect.fromLTRBR(30, 96, 70, 118, const Radius.circular(12)),
      fill,
    );
    for (final x in const [30.0, 51.0]) {
      canvas.drawRRect(
        RRect.fromLTRBR(x, 108, x + 19, 196, const Radius.circular(8)),
        fill,
      );
    }
    for (final MapEntry(key: m, value: list) in ovals.entries) {
      final share = ((sets[m] ?? 0) / MuscleMap.full).clamp(0.0, 1.0) * t;
      final paint = Paint()
        ..color = share == 0
            ? body
            : Color.lerp(color.withValues(alpha: 0.22), color, share)!;
      for (final (x, y, w, h) in list) {
        final rect = Rect.fromCenter(
          center: Offset(x, y),
          width: w * 2,
          height: h * 2,
        );
        final shape = RRect.fromRectAndRadius(rect, Radius.circular(w));
        canvas.drawRRect(
          shape,
          Paint()..color = Color.lerp(body, Colors.black, 0.04)!,
        );
        canvas.drawRRect(shape.deflate(0.6), paint);
        if (m == chosen) {
          canvas.drawRRect(
            shape.inflate(1.2),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = ink,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.t != t ||
      old.chosen != chosen ||
      old.sets != sets ||
      old.body != body ||
      old.color != color;
}
