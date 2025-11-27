import 'package:flutter/material.dart';
import '../colors/quantum_colors.dart';
import 'dart:math' as math;

class QuantumWallpaper extends StatelessWidget {
  final Widget child;
  final double opacity;

  const QuantumWallpaper({
    Key? key,
    required this.child,
    this.opacity = 0.03,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: QuantumColors.darkGradient,
          ),
        ),
        // Quantum wave pattern
        Positioned.fill(
          child: Opacity(
            opacity: opacity,
            child: CustomPaint(
              painter: QuantumWavePatternPainter(),
            ),
          ),
        ),
        // Main content
        child,
      ],
    );
  }
}

class QuantumWavePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = QuantumColors.neonCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final glowPaint = Paint()
      ..color = QuantumColors.neonCyan.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Draw quantum interference pattern
    const gridSize = 50.0;
    const waveAmplitude = 20.0;
    
    // Vertical lines with wave distortion
    for (double x = 0; x < size.width; x += gridSize) {
      final path = Path();
      path.moveTo(x, 0);
      
      for (double y = 0; y < size.height; y += 10) {
        final wave = math.sin(y / 50) * waveAmplitude * math.cos(x / 100);
        path.lineTo(x + wave, y);
      }
      
      canvas.drawPath(path, paint);
      if (x % (gridSize * 3) == 0) {
        canvas.drawPath(path, glowPaint);
      }
    }
    
    // Horizontal lines with wave distortion
    for (double y = 0; y < size.height; y += gridSize) {
      final path = Path();
      path.moveTo(0, y);
      
      for (double x = 0; x < size.width; x += 10) {
        final wave = math.sin(x / 50) * waveAmplitude * math.cos(y / 100);
        path.lineTo(x, y + wave);
      }
      
      canvas.drawPath(path, paint);
      if (y % (gridSize * 3) == 0) {
        canvas.drawPath(path, glowPaint);
      }
    }
    
    // Add quantum nodes at intersections
    final nodePaint = Paint()
      ..color = QuantumColors.neonMagenta.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    final nodeGlowPaint = Paint()
      ..color = QuantumColors.neonMagenta.withOpacity(0.2)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    for (double x = gridSize * 2; x < size.width; x += gridSize * 3) {
      for (double y = gridSize * 2; y < size.height; y += gridSize * 3) {
        // Add some randomness to node positions
        final offsetX = (math.sin(x + y) * 10).toDouble();
        final offsetY = (math.cos(x - y) * 10).toDouble();
        
        canvas.drawCircle(
          Offset(x + offsetX, y + offsetY),
          8,
          nodeGlowPaint,
        );
        canvas.drawCircle(
          Offset(x + offsetX, y + offsetY),
          4,
          nodePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AnimatedQuantumBackground extends StatefulWidget {
  final Widget child;
  final double opacity;

  const AnimatedQuantumBackground({
    Key? key,
    required this.child,
    this.opacity = 0.05,
  }) : super(key: key);

  @override
  State<AnimatedQuantumBackground> createState() => _AnimatedQuantumBackgroundState();
}

class _AnimatedQuantumBackgroundState extends State<AnimatedQuantumBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: QuantumColors.darkGradient,
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Opacity(
                opacity: widget.opacity,
                child: CustomPaint(
                  painter: AnimatedQuantumPatternPainter(
                    animation: _animation.value,
                  ),
                ),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class AnimatedQuantumPatternPainter extends CustomPainter {
  final double animation;

  AnimatedQuantumPatternPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = QuantumColors.neonCyan.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw animated quantum particles
    final particleCount = 50;
    final random = math.Random(42); // Fixed seed for consistent pattern
    
    for (int i = 0; i < particleCount; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final radius = 20 + random.nextDouble() * 30;
      
      // Animate position based on sine wave
      final x = baseX + math.sin(animation * 2 * math.pi + i) * radius;
      final y = baseY + math.cos(animation * 2 * math.pi + i) * radius;
      
      final opacity = (0.3 + 0.7 * math.sin(animation * math.pi + i)).clamp(0.0, 1.0);
      
      paint.color = QuantumColors.neonCyan.withOpacity(opacity * 0.3);
      
      // Draw particle trail
      final path = Path();
      path.moveTo(baseX, baseY);
      path.quadraticBezierTo(
        (baseX + x) / 2 + radius * math.sin(animation * math.pi),
        (baseY + y) / 2 + radius * math.cos(animation * math.pi),
        x,
        y,
      );
      
      canvas.drawPath(path, paint);
      
      // Draw particle
      final particlePaint = Paint()
        ..color = QuantumColors.neonMagenta.withOpacity(opacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), 3, particlePaint);
    }
  }

  @override
  bool shouldRepaint(AnimatedQuantumPatternPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}