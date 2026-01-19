import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../config/theme/app_colors.dart';

/// Marker types for different stop statuses
enum MarkerType {
  pending,
  delivered,
  failed,
  driver,
}

/// Generates custom markers for the delivery map
class MarkerGenerator {
  // Cache for generated markers
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Generate a numbered marker for a delivery stop
  static Future<BitmapDescriptor> generateNumberedMarker({
    required int number,
    required MarkerType type,
    double size = 48,
  }) async {
    final cacheKey = '${type.name}_$number\_$size';
    
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final Color backgroundColor;
    final Color textColor = Colors.white;
    final String? iconText;

    switch (type) {
      case MarkerType.pending:
        backgroundColor = AppColors.warningYellow;
        iconText = number.toString();
        break;
      case MarkerType.delivered:
        backgroundColor = AppColors.primaryGreen;
        iconText = '✓';
        break;
      case MarkerType.failed:
        backgroundColor = AppColors.errorRed;
        iconText = '✗';
        break;
      case MarkerType.driver:
        backgroundColor = AppColors.accentBlue;
        iconText = null;
        break;
    }

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // Draw outer shadow/border
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 2,
      shadowPaint,
    );

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 2,
      borderPaint,
    );

    // Draw colored circle
    final circlePaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 6,
      circlePaint,
    );

    // Draw text or icon
    if (iconText != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: iconText,
          style: TextStyle(
            color: textColor,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size - textPainter.width) / 2,
          (size - textPainter.height) / 2,
        ),
      );
    } else {
      // Draw inner dot for driver marker
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        size * 0.15,
        innerPaint,
      );
    }

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final descriptor = BitmapDescriptor.bytes(bytes);
    _cache[cacheKey] = descriptor;
    
    return descriptor;
  }

  /// Generate the driver location marker (blue dot)
  static Future<BitmapDescriptor> generateDriverMarker({double size = 56}) async {
    return generateNumberedMarker(
      number: 0,
      type: MarkerType.driver,
      size: size,
    );
  }

  /// Generate marker for a stop based on its status
  static Future<BitmapDescriptor> generateStopMarker({
    required int sequence,
    required bool isDelivered,
    required bool isFailed,
    double size = 48,
  }) async {
    final MarkerType type;
    if (isDelivered) {
      type = MarkerType.delivered;
    } else if (isFailed) {
      type = MarkerType.failed;
    } else {
      type = MarkerType.pending;
    }

    return generateNumberedMarker(
      number: sequence,
      type: type,
      size: size,
    );
  }

  /// Clear the marker cache
  static void clearCache() {
    _cache.clear();
  }
}
