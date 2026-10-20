import 'package:material_ui/material_ui.dart';

/// A seed for [TileBlob] that stays the same for the same [text].
int blobSeed(String text) => text.codeUnits.fold(0, (sum, unit) => sum + unit);

/// A soft shape in a corner of a tile in the expressive rework, a shade off
/// the tile's colour. The paths are built once, in a square of 1, and only
/// scaled when drawn; nothing about them moves.
class TileBlob extends CustomPainter {
  const TileBlob({required this.color, required this.seed});

  final Color color;

  /// Picks one of the shapes and its corner.
  final int seed;

  static final List<Path> _shapes = [
    // A cloud of three rounds.
    Path()
      ..moveTo(0.05, 0.75)
      ..cubicTo(-0.05, 0.45, 0.2, 0.3, 0.38, 0.38)
      ..cubicTo(0.4, 0.08, 0.78, 0.0, 0.88, 0.22)
      ..cubicTo(1.12, 0.22, 1.15, 0.62, 0.95, 0.72)
      ..cubicTo(0.98, 0.98, 0.55, 1.05, 0.45, 0.88)
      ..cubicTo(0.3, 1.0, 0.08, 0.95, 0.05, 0.75)
      ..close(),
    // A pebble.
    Path()
      ..moveTo(0.12, 0.5)
      ..cubicTo(0.08, 0.18, 0.45, 0.02, 0.72, 0.1)
      ..cubicTo(0.98, 0.18, 1.04, 0.55, 0.9, 0.78)
      ..cubicTo(0.74, 1.02, 0.3, 1.0, 0.18, 0.82)
      ..cubicTo(0.12, 0.72, 0.13, 0.6, 0.12, 0.5)
      ..close(),
    // A wave of four lobes.
    Path()
      ..moveTo(0.0, 0.62)
      ..cubicTo(0.05, 0.38, 0.28, 0.38, 0.32, 0.5)
      ..cubicTo(0.32, 0.2, 0.62, 0.18, 0.64, 0.4)
      ..cubicTo(0.7, 0.2, 1.0, 0.28, 0.96, 0.52)
      ..cubicTo(1.1, 0.7, 0.95, 1.0, 0.7, 0.96)
      ..lineTo(0.15, 0.98)
      ..cubicTo(-0.02, 0.95, -0.04, 0.8, 0.0, 0.62)
      ..close(),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shape = _shapes[seed % _shapes.length];
    final side = size.shortestSide * 0.95;
    // Hangs over the right edge, at the top or the bottom.
    final top = seed ~/ _shapes.length % 2 == 0;
    canvas
      ..save()
      ..translate(
        size.width - side * 0.62,
        top ? -side * 0.28 : size.height - side * 0.7,
      )
      ..scale(side)
      ..drawPath(shape, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(TileBlob oldDelegate) =>
      oldDelegate.color != color || oldDelegate.seed != seed;
}
