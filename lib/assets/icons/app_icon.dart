import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../theme/colors/quantum_colors.dart';

class AppIconPainter extends CustomPainter {
  final bool isAdaptive;

  AppIconPainter({this.isAdaptive = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // Background gradient
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          QuantumColors.backgroundTertiary,
          QuantumColors.backgroundPrimary,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5));

    if (!isAdaptive) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
    }

    // Draw quantum wave pattern
    final wavePaint = Paint()
      ..color = QuantumColors.neonCyan.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final wavePath = Path();
    for (double i = 0; i <= size.width; i += 5) {
      final y = center.dy + math.sin(i / 20) * radius * 0.3;
      if (i == 0) {
        wavePath.moveTo(i, y);
      } else {
        wavePath.lineTo(i, y);
      }
    }
    canvas.drawPath(wavePath, wavePaint);

    // Draw stylized Q
    final qPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          QuantumColors.neonCyan,
          QuantumColors.neonMagenta,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final qPath = Path();

    // Outer circle of Q
    qPath.addOval(Rect.fromCircle(center: center, radius: radius));

    // Inner cutout
    final innerRadius = radius * 0.6;
    final innerPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: innerRadius));

    // Tail of Q
    final tailPath = Path()
      ..moveTo(center.dx + radius * 0.7, center.dy + radius * 0.7)
      ..lineTo(center.dx + radius * 1.1, center.dy + radius * 1.1)
      ..lineTo(center.dx + radius * 0.9, center.dy + radius * 1.1)
      ..lineTo(center.dx + radius * 0.5, center.dy + radius * 0.7)
      ..close();

    // Combine paths
    final combinedPath = Path.combine(PathOperation.difference, qPath, innerPath);
    final finalPath = Path.combine(PathOperation.union, combinedPath, tailPath);

    canvas.drawPath(finalPath, qPaint);

    // Add glow effect
    final glowPaint = Paint()
      ..color = QuantumColors.neonCyan.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..style = PaintingStyle.fill;

    canvas.drawPath(finalPath, glowPaint);

    // Add quantum nodes
    final nodePaint = Paint()
      ..color = QuantumColors.neonMagenta
      ..style = PaintingStyle.fill;

    final nodeGlow = Paint()
      ..color = QuantumColors.neonMagenta.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
      ..style = PaintingStyle.fill;

    // Place nodes at strategic points
    final nodePositions = [
      Offset(center.dx - radius * 0.8, center.dy),
      Offset(center.dx + radius * 0.8, center.dy),
      Offset(center.dx, center.dy - radius * 0.8),
      Offset(center.dx, center.dy + radius * 0.8),
    ];

    for (final pos in nodePositions) {
      canvas.drawCircle(pos, 4, nodeGlow);
      canvas.drawCircle(pos, 2, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppIcon extends StatelessWidget {
  final double size;
  final bool isAdaptive;

  const AppIcon({
    super.key,
    this.size = 192,
    this.isAdaptive = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: AppIconPainter(isAdaptive: isAdaptive),
    );
  }
}