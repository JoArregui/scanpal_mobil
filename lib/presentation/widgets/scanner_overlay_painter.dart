import 'package:flutter/material.dart';

class ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final Color overlayColor;

  ScannerOverlayPainter({
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Ajustamos el tamaño del visor para que quepa en el contenedor más pequeño
    final double cutOutWidth = size.width * 0.7;
    final double cutOutHeight = size.height * 0.6;

    final left = (size.width - cutOutWidth) / 2;
    final top = (size.height - cutOutHeight) / 2;

    final backgroundPaint = Paint()..color = overlayColor;
    final cutOutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, cutOutWidth, cutOutHeight),
      Radius.circular(borderRadius),
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(cutOutRect),
      ),
      backgroundPaint,
    );

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawRRect(cutOutRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}