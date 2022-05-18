import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import '../camera/camera_image_cropper.dart';

class CropRectPainter extends CustomPainter {
  CropRectPainter(this.cropRect, this.rotation);

  final CropRect cropRect;
  final InputImageRotation rotation;

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    final double left = size.width * cropRect.left;
    final double top = size.height * cropRect.top;
    final double width = size.width * cropRect.width;
    final double height = size.height * cropRect.height;

    canvas.drawRect(
      Rect.fromLTWH(left, top, width, height),
      paint,
    );

    paint = Paint()..color = Colors.black54;

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRect(Rect.fromLTWH(left, top, width, height))
          ..close(),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(CropRectPainter oldDelegate) => true;
}
