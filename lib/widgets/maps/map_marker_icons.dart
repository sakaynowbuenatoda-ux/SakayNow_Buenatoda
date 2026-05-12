import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarkerIcons {
  final BitmapDescriptor pickup;
  final BitmapDescriptor current;
  final BitmapDescriptor dropoff;

  const MapMarkerIcons({
    required this.pickup,
    required this.current,
    required this.dropoff,
  });

  static Future<MapMarkerIcons> load() async {
    final pickup = await _pin(const Color(0xFF16A34A));
    final current = await _pin(const Color(0xFFDC2626));
    final dropoff = await _pin(const Color(0xFF030213));

    return MapMarkerIcons(pickup: pickup, current: current, dropoff: dropoff);
  }

  static Future<BitmapDescriptor> _pin(Color color) async {
    const width = 42.0;
    const height = 56.0;
    const scale = 3.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, width * scale, height * scale),
    )..scale(scale);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final pinPath = Path()
      ..moveTo(width / 2, height - 4)
      ..cubicTo(17, 43, 7, 31, 7, 21)
      ..cubicTo(7, 10, 16, 3, width / 2, 3)
      ..cubicTo(26, 3, 35, 10, 35, 21)
      ..cubicTo(35, 31, 25, 43, width / 2, height - 4)
      ..close();

    canvas.drawPath(pinPath.shift(const Offset(0, 1.5)), shadowPaint);
    canvas.drawPath(pinPath, Paint()..color = color);
    canvas.drawCircle(
      const Offset(width / 2, 21),
      7,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(const Offset(width / 2, 21), 3.5, Paint()..color = color);

    final image = await recorder.endRecording().toImage(
      (width * scale).round(),
      (height * scale).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: width,
      height: height,
      imagePixelRatio: scale,
    );
  }
}
