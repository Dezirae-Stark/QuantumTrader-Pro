import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'lib/assets/icons/app_icon.dart';

class IconGenerator {
  static Future<void> generateAppIcons() async {
    // Generate regular icon (512x512)
    final regularIcon = await _generateIcon(512, false);
    await _saveImage(regularIcon, 'assets/icons/app_icon.png');
    
    // Generate adaptive icon foreground (512x512)
    final adaptiveIcon = await _generateIcon(512, true);
    await _saveImage(adaptiveIcon, 'assets/icons/app_icon_adaptive.png');
    
    print('Icons generated successfully!');
  }

  static Future<Uint8List> _generateIcon(int size, bool isAdaptive) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final painter = AppIconPainter(isAdaptive: isAdaptive);
    
    painter.paint(canvas, Size(size.toDouble(), size.toDouble()));
    
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }

  static Future<void> _saveImage(Uint8List imageData, String path) async {
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(imageData);
  }
}