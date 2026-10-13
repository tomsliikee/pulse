import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import '../../../widgets/scene_kit.dart';
import 'stage.dart';

/// Where a workout takes place.
enum SceneSetting {
  /// Hills under a sun, passing by.
  land,

  /// A hall with wall bars and a window.
  gym,

  /// A quiet room with a mat.
  studio,
  pool,
  sea,

  /// Mountains, and snow that falls.
  snow,

  /// Flat ground to play on, with what the game needs.
  field,
  rock,

  /// High up, the land far below.
  sky,

  /// Under water.
  deep;

  static SceneSetting of(WorkoutType type) => switch (type) {
    WorkoutType.treadmill ||
    WorkoutType.stationaryBike ||
    WorkoutType.stairMachine ||
    WorkoutType.rowingMachine ||
    WorkoutType.elliptical ||
    WorkoutType.hiit ||
    WorkoutType.boxing ||
    WorkoutType.martialArts ||
    WorkoutType.fencing ||
    WorkoutType.strength ||
    WorkoutType.weights ||
    WorkoutType.calisthenics ||
    WorkoutType.gymnastics => gym,
    WorkoutType.dance ||
    WorkoutType.yoga ||
    WorkoutType.pilates ||
    WorkoutType.breathing => studio,
    WorkoutType.swim || WorkoutType.waterPolo => pool,
    WorkoutType.openWater ||
    WorkoutType.surfing ||
    WorkoutType.sailing ||
    WorkoutType.rowing => sea,
    WorkoutType.scuba => deep,
    WorkoutType.paragliding => sky,
    WorkoutType.climbing => rock,
    _ => switch (type.family) {
      WorkoutFamily.winter => snow,
      WorkoutFamily.ball => field,
      _ => land,
    },
  };

  /// Whether the scene is indoors, so it has no sun.
  bool get indoors => this == gym || this == studio;
}

/// How high above the ground the water of a [SceneSetting.sea] stands.
const double seaLevel = 9;

/// Draws [setting] behind the figure of [s].
void paintSetting(Stage s, SceneSetting setting) {
  switch (setting) {
    case SceneSetting.land:
      _sun(s);
      _land(s);
      paintGroundLine(s);
    case SceneSetting.gym:
      _window(s);
      _wallBars(s);
      _hallFloor(s);
    case SceneSetting.studio:
      _window(s);
      _plant(s);
      _hallFloor(s);
      _mat(s);
    case SceneSetting.pool:
      _sun(s);
      _poolSide(s);
    case SceneSetting.sea:
      _sun(s);
      _coast(s);
    case SceneSetting.snow:
      _sun(s);
      _mountains(s);
      _snowGround(s);
      _flakes(s);
    case SceneSetting.field:
      _sun(s);
      _hills(s, s.ground + s.drop * 1.4, s.travelled * 0.07, 30, 0.7, 0.3);
      _pitch(s);
      _gear(s);
    case SceneSetting.rock:
      _sun(s);
      _wall(s);
    case SceneSetting.sky:
      _sun(s);
      _clouds(s);
      _farLand(s);
    case SceneSetting.deep:
      _depth(s);
  }
}

/// A pale sun whose light breathes; it climbs to its place when the scene
/// comes in.
void _sun(Stage s) {
  final u = s.u;
  final centre = Offset(s.size.width - 26 * u, (24 + 50 * s.enter.drop) * u);
  paintGlow(
    s.canvas,
    centre,
    (23 + 1.2 * math.sin(s.time * 1.3)) * u,
    s.accent.withValues(alpha: 0.3),
  );
  s.canvas.drawCircle(centre, 9 * u, s.fill(s.accent.withValues(alpha: 0.4)));
}

/// A row of soft hills, [shift] pixels along; [peaked] gives them tips.
void _hills(
  Stage s,
  double ground,
  double shift,
  double height,
  double waves,
  double opacity, {
  Color? color,
  bool peaked = false,
}) {
  final size = s.size;
  // In hundredths of the scene's height, like every other length.
  height *= s.u;
  final length = size.width / waves;
  // Down to the edge, so a row that is still rising has no gap below it.
  final path = Path()..moveTo(0, size.height);
  for (var x = 0.0; x <= size.width + 4; x += 4) {
    final along = (x + shift) / length * tau;
    final rise = peaked
        ? 1 -
              (math.asin(math.sin(along)).abs() / (math.pi / 2)) * 0.75 -
              0.12 * math.sin(along * 2.7).abs()
        : 0.5 + 0.32 * math.sin(along) + 0.18 * math.sin(along * 2.3);
    path.lineTo(x, ground - height * rise);
  }
  path
    ..lineTo(size.width, size.height)
    ..close();
  s.canvas.drawPath(path, s.fill((color ?? s.soft).withValues(alpha: opacity)));
}

void _land(Stage s) {
  _hills(s, s.ground + s.drop * 1.4, s.travelled * 0.07, 33, 0.7, 0.3);
  _hills(s, s.ground + s.drop, s.travelled * 0.18, 26, 0.9, 0.55);
  _hills(s, s.ground + s.drop * 0.6, s.travelled * 0.45, 15, 1.7, 0.9);
}

/// The line the figure stands on, with marks that pass by.
void paintGroundLine(Stage s, {bool marks = true}) {
  final u = s.u;
  final line = s.stroke(s.scheme.outlineVariant, 2.2);
  s.canvas.drawLine(
    Offset(8 * u, s.floor),
    Offset(s.size.width - 8 * u, s.floor),
    line,
  );
  if (!marks) return;
  final gap = 38 * u;
  for (var x = -(s.travelled % gap); x < s.size.width; x += gap) {
    if (x < 12 * u || x > s.size.width - 20 * u) continue;
    s.canvas.drawLine(
      Offset(x, s.ground + 8.5 * u),
      Offset(x + 9 * u, s.ground + 8.5 * u),
      line,
    );
  }
}

/// The floor of a hall: a band that rises when the scene comes in.
void _hallFloor(Stage s) {
  final top = s.floor + s.drop;
  s.canvas.drawRect(
    Rect.fromLTRB(0, top, s.size.width, s.size.height),
    s.fill(s.soft.withValues(alpha: 0.7)),
  );
  // Boards that run towards the viewer.
  final board = s.stroke(s.scheme.outlineVariant.withValues(alpha: 0.6), 1);
  final gap = 30 * s.u;
  for (var x = gap / 2; x < s.size.width; x += gap) {
    final lean = (x - s.size.width / 2) * 0.12;
    s.canvas.drawLine(
      Offset(x, top + 2 * s.u),
      Offset(x + lean, s.size.height),
      board,
    );
  }
  s.canvas.drawLine(
    Offset(0, top),
    Offset(s.size.width, top),
    s.stroke(s.scheme.outlineVariant, 2.2),
  );
}

/// A window with the light of the day in it and on the floor below.
void _window(Stage s) {
  final u = s.u;
  final rect = Rect.fromLTWH(
    s.size.width - 58 * u,
    (12 - 60 * s.enter.drop) * u,
    40 * u,
    34 * u,
  );
  final light = 0.2 + 0.04 * math.sin(s.time * 1.3);
  paintGlow(
    s.canvas,
    rect.center,
    42 * u,
    s.accent.withValues(alpha: light * 0.8),
  );
  final shape = RRect.fromRectAndRadius(rect, Radius.circular(6 * u));
  final frame = s.stroke(s.scheme.outlineVariant, 2);
  s.canvas
    ..drawRRect(shape, s.fill(s.accent.withValues(alpha: light)))
    ..drawRRect(shape, frame)
    ..drawLine(rect.topCenter, rect.bottomCenter, frame)
    ..drawLine(rect.centerLeft, rect.centerRight, frame);
  // What falls through it lies on the floor as a slanted patch.
  final patch = Path()
    ..moveTo(rect.left - 34 * u, s.floor + 2 * u)
    ..lineTo(rect.right - 30 * u, s.floor + 2 * u)
    ..lineTo(rect.right - 52 * u, s.size.height)
    ..lineTo(rect.left - 62 * u, s.size.height)
    ..close();
  s.canvas.drawPath(
    patch,
    s.fill(s.accent.withValues(alpha: light * 0.5 * s.enter.shown)),
  );
}

void _wallBars(Stage s) {
  final u = s.u;
  final paint = s.stroke(s.scheme.outlineVariant, 2);
  final top = (18 + 70 * s.enter.drop) * u;
  final bottom = s.floor + s.drop;
  for (final x in [14 * u, 40 * u]) {
    s.canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
  }
  for (var y = top + 5 * u; y < bottom - 3 * u; y += 8 * u) {
    s.canvas.drawLine(Offset(14 * u, y), Offset(40 * u, y), paint);
  }
}

/// A plant in a pot, its leaves moving a little.
void _plant(Stage s) {
  final u = s.u;
  final foot = Offset(26 * u, s.floor + s.drop);
  final leaf = s.stroke(s.scheme.primary.withValues(alpha: 0.45), 4.5);
  for (var i = 0; i < 5; i++) {
    final lean = (i - 2) * 0.42 + 0.05 * math.sin(s.time * 0.9 + i);
    final tip =
        foot +
        Offset(math.sin(lean), -math.cos(lean)) * (30 - (i - 2).abs() * 4) * u;
    final bend =
        foot + Offset(math.sin(lean * 0.4), -math.cos(lean * 0.4)) * 18 * u;
    s.canvas.drawPath(
      Path()
        ..moveTo(foot.dx, foot.dy - 9 * u)
        ..quadraticBezierTo(bend.dx, bend.dy, tip.dx, tip.dy),
      leaf,
    );
  }
  s.canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(
        foot.dx - 8 * u,
        foot.dy - 11 * u,
        foot.dx + 8 * u,
        foot.dy,
      ),
      Radius.circular(3 * u),
    ),
    s.fill(s.accent.withValues(alpha: 0.75)),
  );
}

void _mat(Stage s) {
  final u = s.u;
  s.canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(
        s.centre - 52 * u,
        s.floor + s.drop,
        s.centre + 52 * u,
        s.floor + s.drop + 5 * u,
      ),
      Radius.circular(2.5 * u),
    ),
    s.fill(s.accent.withValues(alpha: 0.55)),
  );
}

/// The far edge of a pool.
void _poolSide(Stage s) {
  final u = s.u;
  final y = s.size.height * 0.5 + s.drop;
  s.canvas.drawRect(
    Rect.fromLTRB(0, y - 6 * u, s.size.width, y + 4 * u),
    s.fill(s.scheme.outlineVariant.withValues(alpha: 0.5)),
  );
  final gap = 16 * u;
  final tile = s.stroke(s.scheme.surfaceBright.withValues(alpha: 0.7), 1);
  for (var x = -(s.travelled * 0.5 % gap); x < s.size.width; x += gap) {
    s.canvas.drawLine(Offset(x, y - 6 * u), Offset(x, y + 4 * u), tile);
  }
}

/// A far shore across the water, and the water up to it.
void _coast(Stage s) {
  final horizon = s.ground - (seaLevel + 12) * s.u + s.drop;
  _hills(s, horizon + 2 * s.u, s.travelled * 0.05, 16, 0.8, 0.4);
  s.canvas.drawRect(
    Rect.fromLTRB(0, horizon, s.size.width, s.size.height),
    s.fill(s.scheme.secondaryContainer.withValues(alpha: 0.6)),
  );
  // Light on the water under the sun.
  final glint = s.stroke(s.accent.withValues(alpha: 0.35), 1.4);
  for (var i = 0; i < 4; i++) {
    final wide = (5 + i * 4 + 2 * math.sin(s.time * 1.6 + i)) * s.u;
    final x = s.size.width - 26 * s.u;
    final y = horizon + (2.5 + i * 2.6) * s.u;
    s.canvas.drawLine(Offset(x - wide, y), Offset(x + wide, y), glint);
  }
}

/// Water with waves from [level] above the ground down to the edge,
/// [shift] pixels along.
void paintWater(
  Stage s,
  double level,
  double shift, {
  double opacity = 0.88,
  double waves = 2.4,
}) {
  final u = s.u;
  final top = s.ground - level * u;
  final path = Path()..moveTo(0, s.size.height);
  for (var x = 0.0; x <= s.size.width + 4; x += 4) {
    path.lineTo(x, top + waves * u * math.sin((x + shift) / (16 * u)));
  }
  path
    ..lineTo(s.size.width, s.size.height)
    ..close();
  s.canvas.drawPath(
    path,
    s.fill(s.scheme.secondaryContainer.withValues(alpha: opacity)),
  );
}

void _mountains(Stage s) {
  _hills(
    s,
    s.ground + s.drop * 1.6,
    s.travelled * 0.03,
    62,
    1.3,
    0.35,
    peaked: true,
  );
  _hills(
    s,
    s.ground + s.drop * 1.2,
    s.travelled * 0.08 + 90 * s.u,
    44,
    1.9,
    0.5,
    peaked: true,
  );
}

void _snowGround(Stage s) {
  _hills(s, s.ground + s.drop, s.travelled * 0.2, 22, 1.1, 0.75, color: s.pale);
  _hills(
    s,
    s.ground + 4 * s.u + s.drop * 0.6,
    s.travelled * 0.5,
    8,
    1.9,
    1,
    color: s.pale,
  );
  // Tracks left in the snow.
  final track = s.stroke(s.scheme.outlineVariant.withValues(alpha: 0.7), 1.6);
  final gap = 30 * s.u;
  for (var x = -(s.travelled % gap); x < s.size.width; x += gap) {
    s.canvas.drawLine(
      Offset(x, s.ground + 9 * s.u),
      Offset(x + 12 * s.u, s.ground + 9 * s.u),
      track,
    );
  }
}

void _flakes(Stage s) {
  final u = s.u;
  final paint = s.fill(s.pale.withValues(alpha: 0.9 * s.enter.shown));
  for (var i = 0; i < 22; i++) {
    final speed = 9 + i % 5 * 3.0;
    final fall = (s.time * speed + i * 37) % 100;
    final across =
        (i * 61.8 - s.travelled / u * 0.3 + 3 * math.sin(s.time + i)) %
        (s.size.width / u);
    s.canvas.drawCircle(
      Offset(across * u, fall * u),
      (0.9 + i % 3 * 0.45) * u,
      paint,
    );
  }
}

/// Flat ground to play on, with a line along its far side.
void _pitch(Stage s) {
  final top = s.floor - 9 * s.u + s.drop;
  s.canvas.drawRect(
    Rect.fromLTRB(0, top, s.size.width, s.size.height),
    s.fill(s.soft.withValues(alpha: 0.85)),
  );
  s.canvas.drawLine(
    Offset(0, top + 4 * s.u),
    Offset(s.size.width, top + 4 * s.u),
    s.stroke(s.scheme.surfaceBright.withValues(alpha: 0.7), 1.2),
  );
}

/// What stands on the field of the game: a goal, a net, a basket, a flag.
void _gear(Stage s) {
  final u = s.u;
  final canvas = s.canvas;
  final post = s.stroke(s.scheme.onSurfaceVariant, 2.4);
  final mesh = s.stroke(s.scheme.onSurfaceVariant.withValues(alpha: 0.5), 0.9);
  // It rises out of the ground with the land.
  canvas
    ..save()
    ..translate(0, s.drop * 2);

  void net(double x, double height, {double foot = 0}) {
    final base = s.at(x, foot - 3.4);
    final top = s.at(x, height);
    final back = Offset(14 * u, -7 * u);
    for (var i = 0; i <= 4; i++) {
      final from = Offset.lerp(base, top, 0.45 + i * 0.1375)!;
      canvas.drawLine(from, from + back, mesh);
    }
    for (var i = 0; i <= 3; i++) {
      final shift = back * (i / 3);
      canvas.drawLine(Offset.lerp(base, top, 0.45)! + shift, top + shift, mesh);
    }
    canvas
      ..drawLine(base, top, post)
      ..drawLine(top, top + back, post);
  }

  void goal(double x, double height) {
    final base = s.at(x, -3.4);
    final top = s.at(x, height);
    final back = s.at(x + 30, -3.4);
    for (var i = 1; i <= 5; i++) {
      final t = i / 6;
      canvas
        ..drawLine(Offset.lerp(top, base, t)!, Offset.lerp(top, back, t)!, mesh)
        ..drawLine(
          Offset.lerp(base, back, t)!,
          Offset.lerp(top, back, t * 0.9)!,
          mesh,
        );
    }
    canvas
      ..drawLine(top, back, mesh)
      ..drawLine(base, top, post);
  }

  switch (s.type) {
    case WorkoutType.soccer ||
        WorkoutType.handball ||
        WorkoutType.americanFootball ||
        WorkoutType.australianFootball ||
        WorkoutType.rugby:
      goal(78, s.type == WorkoutType.handball ? 36 : 50);
    case WorkoutType.tennis:
      net(62, 14);
    case WorkoutType.badminton:
      net(62, 30);
    case WorkoutType.volleyball:
      net(46, 46);
    case WorkoutType.tableTennis:
      final table = s.stroke(s.scheme.onSurfaceVariant, 2.6);
      canvas
        ..drawLine(s.at(26, 19), s.at(96, 19), table)
        ..drawLine(s.at(34, 19), s.at(34, -3.4), post)
        ..drawLine(s.at(88, 19), s.at(88, -3.4), post)
        ..drawLine(s.at(61, 19), s.at(61, 26), post);
    case WorkoutType.basketball:
      final ring = s.stroke(s.accent, 2);
      canvas
        ..drawLine(s.at(92, -3.4), s.at(92, 60), post)
        ..drawLine(s.at(92, 60), s.at(84, 62), post)
        ..drawLine(s.at(84, 54), s.at(84, 74), s.stroke(post.color, 3.2))
        ..drawLine(s.at(84, 58), s.at(70, 58), ring);
      for (var i = 0; i <= 4; i++) {
        canvas.drawLine(
          s.at(70 + i * 3.5, 58),
          s.at(72.5 + i * 2.25, 47),
          mesh,
        );
      }
    case WorkoutType.cricket:
      for (final x in [-22.0, -19.0, -16.0]) {
        canvas.drawLine(s.at(x, -3.4), s.at(x, 20), post);
      }
    case WorkoutType.golf:
      canvas.drawLine(s.at(96, -3.4), s.at(96, 34), post);
      final wave = 2 * math.sin(s.time * 3);
      canvas.drawPath(
        Path()
          ..moveTo(s.at(96, 34).dx, s.at(96, 34).dy)
          ..lineTo(s.at(110, 30 + wave).dx, s.at(110, 30 + wave).dy)
          ..lineTo(s.at(96, 25).dx, s.at(96, 25).dy)
          ..close(),
        s.fill(s.accent),
      );
    default:
  }
  canvas.restore();
}

/// A rock face that fills the scene but for a strip of sky.
void _wall(Stage s) {
  final u = s.u;
  final size = s.size;
  // Its edge is rough, and passes downwards as the figure climbs.
  final climbed = s.travelled;
  final path = Path()..moveTo(0, -4);
  for (var y = -4.0; y <= size.height + 4; y += 4) {
    final along = (y - climbed) / (30 * u);
    path.lineTo(
      size.width -
          (44 + 9 * math.sin(along) + 5 * math.sin(along * 2.7)) * u +
          s.enter.drop * 40 * u,
      y,
    );
  }
  path
    ..lineTo(0, size.height + 4)
    ..close();
  s.canvas.drawPath(path, s.fill(s.soft.withValues(alpha: 0.85)));
  // Cracks in it.
  final crack = s.stroke(s.scheme.outlineVariant.withValues(alpha: 0.7), 1.2);
  final gap = 46 * u;
  for (var i = 0; i < 7; i++) {
    final x = (10 + i * 37 % 150) * u;
    final y = (i * 29 * u + climbed) % (size.height + gap) - gap / 2;
    s.canvas.drawPath(
      Path()
        ..moveTo(x, y)
        ..lineTo(x + 5 * u, y + 7 * u)
        ..lineTo(x + 2 * u, y + 15 * u),
      crack,
    );
  }
}

void _clouds(Stage s) {
  final u = s.u;
  final paint = s.fill(s.pale.withValues(alpha: 0.75 * s.enter.shown));
  final wide = s.size.width + 80 * u;
  for (var i = 0; i < 4; i++) {
    final x =
        wide - (s.travelled * (0.5 + i * 0.2) + i * wide / 4) % wide - 40 * u;
    final y = (16 + i * 17 + 1.5 * math.sin(s.time * 0.7 + i)) * u;
    for (final (dx, dy, r) in const [
      (0.0, 0.0, 7.0),
      (8.0, -3.0, 8.5),
      (17.0, 0.5, 6.5),
    ]) {
      s.canvas.drawCircle(Offset(x + dx * u, y + dy * u), r * u, paint);
    }
  }
}

/// Land seen from high above: low, pale and slow.
void _farLand(Stage s) {
  final ground = s.size.height + 4 * s.u;
  _hills(s, ground + s.drop * 1.4, s.travelled * 0.1, 26, 0.9, 0.35);
  _hills(s, ground + s.drop, s.travelled * 0.22, 16, 1.5, 0.6);
}

/// Water from top to bottom, darker further down, with light falling in
/// and the ground of the sea passing below.
void _depth(Stage s) {
  final u = s.u;
  final size = s.size;
  s.canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          s.scheme.secondaryContainer.withValues(alpha: 0.5),
          Color.lerp(s.scheme.secondaryContainer, s.scheme.secondary, 0.45)!,
        ],
      ).createShader(Offset.zero & size),
  );
  for (var i = 0; i < 4; i++) {
    final x =
        (0.15 + i * 0.24) * size.width + 6 * u * math.sin(s.time * 0.5 + i);
    final wide = (9 + i % 2 * 5) * u;
    s.canvas.drawPath(
      Path()
        ..moveTo(x, 0)
        ..lineTo(x + wide, 0)
        ..lineTo(x + wide - 26 * u, size.height)
        ..lineTo(x - 34 * u, size.height)
        ..close(),
      s.fill(
        s.pale.withValues(
          alpha: (0.1 + 0.04 * math.sin(s.time + i * 2)) * s.enter.shown,
        ),
      ),
    );
  }
  _hills(
    s,
    size.height + 6 * u + s.drop,
    s.travelled * 0.6,
    24,
    1.6,
    0.55,
    color: s.scheme.secondary,
  );
  // Weed that sways.
  final weed = s.stroke(s.scheme.primary.withValues(alpha: 0.4), 3);
  final gap = 54 * u;
  for (var x = -(s.travelled * 0.6 % gap); x < size.width + gap; x += gap) {
    for (var blade = 0; blade < 3; blade++) {
      final foot = Offset(x + blade * 6 * u, size.height + s.drop);
      final sway = 5 * u * math.sin(s.time * 1.2 + x / gap + blade);
      s.canvas.drawPath(
        Path()
          ..moveTo(foot.dx, foot.dy)
          ..quadraticBezierTo(
            foot.dx - sway,
            foot.dy - 12 * u,
            foot.dx + sway,
            foot.dy - (20 + blade * 5) * u,
          ),
        weed,
      );
    }
  }
}
