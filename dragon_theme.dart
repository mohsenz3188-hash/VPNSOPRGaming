import 'dart:math' as math;
import 'package:flutter/material.dart';

class DragonColors {
  static const Color oledBlack = Color(0xFF06070B);
  static const Color charcoal = Color(0xFF0E121B);
  static const Color cardSurface = Color(0xFF131926);
  static const Color electricBlue = Color(0xFF00E5FF);
  static const Color neonPurple = Color(0xFF7C4DFF);
  static const Color crimsonRed = Color(0xFFFF1744);
  static const Color emberOrange = Color(0xFFFF6D00);
  static const Color textPrimary = Color(0xFFF3F6FC);
  static const Color textSecondary = Color(0xFF8B9BB4);
}

ThemeData buildDragonTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: DragonColors.oledBlack,
    colorScheme: const ColorScheme.dark(
      primary: DragonColors.electricBlue,
      secondary: DragonColors.crimsonRed,
      surface: DragonColors.charcoal,
      error: DragonColors.crimsonRed,
    ),
    cardTheme: CardThemeData(
      color: DragonColors.cardSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: DragonColors.electricBlue.withValues(alpha: 0.16),
          width: 1,
        ),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
  );
}

class DragonScalePainter extends CustomPainter {
  final Color accentColor;
  DragonScalePainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    const double radius = 28;
    const double dx = radius * 1.5;
    final double dy = radius * math.sqrt(3);

    for (double y = -dy; y < size.height + dy; y += dy / 2) {
      final int row = (y / (dy / 2)).round();
      final double xOffset = row.isOdd ? dx : 0;
      for (double x = -dx; x < size.width + dx; x += dx * 2) {
        final center = Offset(x + xOffset, y);
        final path = Path();
        path.addArc(
          Rect.fromCircle(center: center, radius: radius),
          0.15 * math.pi,
          0.70 * math.pi,
        );
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DragonScalePainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}

class DragonLogoPainter extends CustomPainter {
  final Color primary;
  final Color secondary;

  DragonLogoPainter({
    this.primary = DragonColors.electricBlue,
    this.secondary = DragonColors.crimsonRed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shieldPaint = Paint()
      ..shader = LinearGradient(
        colors: [primary, secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;

    final fangPath = Path()
      ..moveTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.88, h * 0.28)
      ..lineTo(w * 0.72, h * 0.82)
      ..lineTo(w * 0.50, h * 0.95)
      ..lineTo(w * 0.28, h * 0.82)
      ..lineTo(w * 0.12, h * 0.28)
      ..close();
    canvas.drawPath(fangPath, shieldPaint);

    final eyePaint = Paint()
      ..color = secondary
      ..style = PaintingStyle.fill;
    final eyePath = Path()
      ..moveTo(w * 0.28, h * 0.44)
      ..lineTo(w * 0.50, h * 0.32)
      ..lineTo(w * 0.72, h * 0.44)
      ..lineTo(w * 0.50, h * 0.68)
      ..close();
    canvas.drawPath(eyePath, eyePaint);
  }

  @override
  bool shouldRepaint(covariant DragonLogoPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.secondary != secondary;
}
