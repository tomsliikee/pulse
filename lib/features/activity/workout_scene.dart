import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../theme/pulse_look.dart';
import '../../widgets/scene_kit.dart';
import 'scene/figures_ball.dart';
import 'scene/figures_calm.dart';
import 'scene/figures_ground.dart';
import 'scene/figures_gym.dart';
import 'scene/figures_water.dart';
import 'scene/figures_winter.dart';
import 'scene/settings.dart';
import 'scene/stage.dart';

/// A small figure doing a workout of [type] where that takes place: on
/// the road, in a hall, on a field, in snow, on or under water, on a rock
/// face. Each kind moves as it does, with what it needs in its hands.
/// Drawn by the app in the colours of the theme. When the page opens the
/// setting rises, the sun climbs to its place and the figure comes in. It
/// stands still where the system asks for no animations.
class WorkoutScene extends StatelessWidget {
  const WorkoutScene({
    super.key,
    required this.type,
    this.height = 150,
    this.stage,
  });

  final WorkoutType type;
  final double height;

  /// The height the scene is drawn for, at the bottom; above it is only
  /// its sky. The whole [height] when null.
  final double? stage;

  @override
  Widget build(BuildContext context) => SceneClock(
    builder: (context, seconds) => CustomPaint(
      size: Size(double.infinity, height),
      painter: _ScenePainter(
        type: type,
        stage: stage,
        scheme: Theme.of(context).colorScheme,
        seconds: seconds,
        still: MediaQuery.disableAnimationsOf(context),
        mascot: PulseLook.mascotOf(context),
      ),
    ),
  );
}

/// How one kind of workout moves.
class _Gait {
  const _Gait(this.cycle, [this.travel = 0]);

  /// Seconds one stride, stroke or round of exercises takes.
  final double cycle;

  /// How fast the ground passes, in scene heights per second.
  final double travel;

  static _Gait of(WorkoutType type) => switch (type) {
    WorkoutType.treadmill => const _Gait(0.72),
    WorkoutType.stationaryBike => const _Gait(0.9),
    WorkoutType.rowingMachine => const _Gait(2.6),
    WorkoutType.sailing => const _Gait(4, 0.5),
    WorkoutType.paragliding => const _Gait(5, 0.35),
    WorkoutType.hiit => const _Gait(0.9),
    WorkoutType.elliptical => const _Gait(1.3),
    WorkoutType.fencing => const _Gait(3.6),
    WorkoutType.golf => const _Gait(4.4),
    WorkoutType.pilates => const _Gait(3.2),
    WorkoutType.breathing => const _Gait(5.5),
    _ => switch (type.figure) {
      WorkoutFigure.walk => const _Gait(1.1, 0.55),
      WorkoutFigure.run => const _Gait(0.72, 1.3),
      WorkoutFigure.hike => const _Gait(1.3, 0.4),
      WorkoutFigure.stairs => const _Gait(1.3),
      WorkoutFigure.ride => const _Gait(0.9, 1.9),
      WorkoutFigure.wheelchair => const _Gait(1.3, 0.6),
      WorkoutFigure.swim => const _Gait(1.7, 0.45),
      WorkoutFigure.paddle => const _Gait(2.6, 0.7),
      WorkoutFigure.board => const _Gait(3, 0.9),
      WorkoutFigure.dive => const _Gait(2.2, 0.3),
      WorkoutFigure.kick => const _Gait(2.2),
      WorkoutFigure.racket => const _Gait(2),
      WorkoutFigure.toss => const _Gait(2.8),
      WorkoutFigure.bat => const _Gait(3),
      WorkoutFigure.glide => const _Gait(2.2, 2),
      WorkoutFigure.skate => const _Gait(1.6, 1.2),
      WorkoutFigure.lift => const _Gait(17),
      WorkoutFigure.bodyweight => const _Gait(15),
      // What passes here is the rock, downwards.
      WorkoutFigure.climb => const _Gait(2.6, 0.085),
      WorkoutFigure.fight => const _Gait(2.8),
      WorkoutFigure.dance => const _Gait(2.2),
      WorkoutFigure.pose => const _Gait(21),
    },
  };
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.type,
    required this.stage,
    required this.scheme,
    required this.seconds,
    required this.still,
    required this.mascot,
  }) : super(repaint: seconds);

  final WorkoutType type;
  final double? stage;
  final ColorScheme scheme;
  final ValueListenable<double> seconds;

  /// Whether nothing moves, so the scene has come in already.
  final bool still;

  /// Whether the figure is the turtle.
  final bool mascot;

  /// A pale sky in the colour of the page, so the scene has an end to fade
  /// from.
  Color get _sky =>
      Color.lerp(scheme.secondaryContainer, scheme.surfaceBright, 0.5)!;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final gait = _Gait.of(type);
    final time = seconds.value;
    final full = size;
    size = Size(full.width, math.min(stage ?? full.height, full.height));
    final setting = SceneSetting.of(type);
    paintSky(
      canvas,
      Offset.zero & full,
      _sky,
      Color.lerp(_sky, scheme.surfaceBright, setting.indoors ? 0.3 : 0.6)!,
    );
    canvas.translate(0, full.height - size.height);
    final s = Stage(
      canvas: canvas,
      size: size,
      scheme: scheme,
      type: type,
      time: time,
      cycle: gait.cycle,
      travel: gait.travel,
      enter: SceneEntrance.at(time, still: still),
      walksIn: type.figure != WorkoutFigure.climb,
      mascot: mascot,
    );
    paintSetting(s, setting);
    s.enter.fade(canvas, s.bounds, () => _figure(s));
  }

  void _figure(Stage s) {
    final pen = s.pen;
    final feet = s.at(0, -3.4);
    // The turtle on four legs is longer than the figure is wide.
    final wide = mascot ? 1.9 : 1.0;
    switch (type.figure) {
      case WorkoutFigure.walk:
        pen.shadow(feet, 13 * wide);
        paintWalker(s);
      case WorkoutFigure.run:
        // Off the ground twice a stride, and the shadow shrinks with it.
        final lift = math.pow(math.sin(s.turn).abs(), 1.4).toDouble();
        if (type == WorkoutType.treadmill) {
          paintTreadmill(s);
        } else {
          pen.shadow(feet, (13 - 5 * lift) * wide, strength: 1 - 0.45 * lift);
          paintWind(s);
          paintDust(s, s.time / s.cycle);
        }
        paintWalker(s, running: true);
      case WorkoutFigure.hike:
        pen.shadow(feet, 14 * wide);
        if (type == WorkoutType.snowshoe) {
          paintDust(s, s.time / s.cycle, color: s.pale);
        }
        paintWalker(s, hiking: true);
      case WorkoutFigure.stairs:
        paintStairs(s);
      case WorkoutFigure.ride:
        pen.shadow(feet, 34);
        if (type != WorkoutType.stationaryBike) paintWind(s, -14);
        paintRider(s, onStand: type == WorkoutType.stationaryBike);
      case WorkoutFigure.wheelchair:
        paintWind(s, -10);
        paintWheelchair(s);
      case WorkoutFigure.swim:
        paintSwimmer(s);
      case WorkoutFigure.paddle:
        paintPaddle(s);
      case WorkoutFigure.board:
        paintBoard(s);
      case WorkoutFigure.dive:
        paintDiver(s);
      case WorkoutFigure.kick:
        paintKick(s);
      case WorkoutFigure.racket:
        paintRacket(s);
      case WorkoutFigure.toss:
        paintToss(s);
        if (type == WorkoutType.waterPolo) paintWater(s, 30, s.time * 9 * s.u);
      case WorkoutFigure.bat:
        paintBat(s);
      case WorkoutFigure.glide:
        paintWind(s, -6);
        paintGlide(s);
      case WorkoutFigure.skate:
        paintWind(s, -4);
        paintSkate(s);
      case WorkoutFigure.lift:
        paintLift(s);
      case WorkoutFigure.bodyweight:
        paintBodyweight(s);
      case WorkoutFigure.climb:
        paintClimb(s);
      case WorkoutFigure.fight:
        paintFight(s);
      case WorkoutFigure.dance:
        paintDance(s);
      case WorkoutFigure.pose:
        paintPosture(s);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.stage != stage ||
      oldDelegate.still != still ||
      oldDelegate.mascot != mascot ||
      oldDelegate.scheme != scheme;
}
