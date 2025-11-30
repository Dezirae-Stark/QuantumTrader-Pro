import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;

void main() async {
  // Create directories
  await Directory('assets/icons').create(recursive: true);
  
  // Generate regular icon
  final icon = await generateIcon(512, false);
  await File('assets/icons/app_icon.png').writeAsBytes(icon);
  
  // Generate adaptive icon
  final adaptiveIcon = await generateIcon(512, true);
  await File('assets/icons/app_icon_adaptive.png').writeAsBytes(adaptiveIcon);
  
  print('Icons generated successfully!');
}

Future<Uint8List> generateIcon(int size, bool isAdaptive) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  final center = ui.Offset(size / 2, size / 2);
  final radius = size * 0.4;
  
  // Background (only for non-adaptive)
  if (!isAdaptive) {
    final bgPaint = ui.Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius * 1.5,
        [const ui.Color(0xFF101018), const ui.Color(0xFF050509)],
      );
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), bgPaint);
  }
  
  // Draw stylized Q with gradient
  final qPaint = ui.Paint()
    ..shader = ui.Gradient.linear(
      ui.Offset(0, 0),
      ui.Offset(size.toDouble(), size.toDouble()),
      [const ui.Color(0xFF00E5FF), const ui.Color(0xFFD500F9)],
    )
    ..style = ui.PaintingStyle.fill;
  
  // Q shape
  final qPath = ui.Path();
  
  // Outer circle
  qPath.addOval(ui.Rect.fromCircle(center: center, radius: radius));
  
  // Inner circle (to create ring)
  final innerPath = ui.Path()
    ..addOval(ui.Rect.fromCircle(center: center, radius: radius * 0.6))
    ..fillType = ui.PathFillType.evenOdd;
  
  // Combine to create ring
  final ringPath = ui.Path.combine(ui.PathOperation.difference, qPath, innerPath);
  
  // Q tail
  final tailPath = ui.Path()
    ..moveTo(center.dx + radius * 0.5, center.dy + radius * 0.5)
    ..lineTo(center.dx + radius * 1.1, center.dy + radius * 1.1)
    ..lineTo(center.dx + radius * 0.9, center.dy + radius * 1.1)
    ..lineTo(center.dx + radius * 0.3, center.dy + radius * 0.5)
    ..close();
  
  // Draw Q
  canvas.drawPath(ringPath, qPaint);
  canvas.drawPath(tailPath, qPaint);
  
  // Add glow
  final glowPaint = ui.Paint()
    ..shader = ui.Gradient.radial(
      center,
      radius,
      [
        const ui.Color(0x8000E5FF),
        const ui.Color(0x0000E5FF),
      ],
    )
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 20);
  
  canvas.drawCircle(center, radius, glowPaint);
  
  // Add quantum nodes
  final nodePaint = ui.Paint()
    ..color = const ui.Color(0xFFD500F9)
    ..style = ui.PaintingStyle.fill;
  
  final nodePositions = [
    ui.Offset(center.dx - radius * 0.8, center.dy),
    ui.Offset(center.dx + radius * 0.8, center.dy),
    ui.Offset(center.dx, center.dy - radius * 0.8),
    ui.Offset(center.dx + radius * 0.4, center.dy + radius * 0.6),
  ];
  
  for (final pos in nodePositions) {
    // Node glow
    final nodeGlow = ui.Paint()
      ..color = const ui.Color(0x80D500F9)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
    canvas.drawCircle(pos, 8, nodeGlow);
    
    // Node center
    canvas.drawCircle(pos, 4, nodePaint);
  }
  
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  
  return byteData!.buffer.asUint8List();
}