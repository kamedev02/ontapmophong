import 'package:flutter/material.dart';

class CustomFlag extends StatelessWidget {
  final double height;
  final Color color;

  const CustomFlag({super.key, required this.height, this.color = Colors.red});

  @override
  Widget build(BuildContext context) {
    const double svgWidth = 20.0;
    const double svgHeight = 20.0;

    final double aspectRatio = svgWidth / svgHeight;

    return CustomPaint(
      size: Size(height * aspectRatio, height),
      painter: FlagPainter(
        color: color,
        canvasHeight: height,
        canvasWidth: height * aspectRatio,
      ),
    );
  }
}

class FlagPainter extends CustomPainter {
  final Color color;
  final double canvasWidth;
  final double canvasHeight;

  FlagPainter({
    required this.color,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double svgWidth = 20.0;
    const double svgHeight = 20.0;
    final double scaleX = canvasWidth / svgWidth;
    final double scaleY = canvasHeight / svgHeight;

    canvas.save();
    canvas.scale(scaleX, scaleY);
    final flagPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final flagPath = Path()
      ..moveTo(11.5, 4.5)
      ..lineTo(17.7056, 4.5)
      ..cubicTo(18.1342, 4.5, 18.3485, 4.5, 18.4776, 4.59027)
      ..cubicTo(18.5903, 4.6691, 18.6655, 4.79086, 18.6856, 4.92692)
      ..cubicTo(18.7086, 5.08273, 18.6128, 5.27442, 18.4211, 5.65777)
      ..lineTo(17.1688, 8.16232)
      ..cubicTo(17.1068, 8.28641, 17.0758, 8.34845, 17.0626, 8.41367)
      ..cubicTo(17.051, 8.47145, 17.0496, 8.53083, 17.0586, 8.58908)
      ..cubicTo(17.0688, 8.65483, 17.097, 8.71822, 17.1533, 8.845)
      ..lineTo(18.5, 11.8751)
      ..cubicTo(18.6667, 12.25, 18.75, 12.4374, 18.7227, 12.5888)
      ..cubicTo(18.6988, 12.721, 18.6227, 12.8381, 18.5116, 12.9136)
      ..cubicTo(18.3844, 13, 18.1793, 13, 17.769, 13)
      ..lineTo(10.1, 13)
      ..cubicTo(9.53995, 13, 9.25992, 13, 9.04601, 12.891)
      ..cubicTo(8.85785, 12.7951, 8.70487, 12.6422, 8.60899, 12.454)
      ..cubicTo(8.5, 12.2401, 8.5, 11.9601, 8.5, 11.4)
      ..lineTo(8.5, 9)
      ..close();
    canvas.drawPath(flagPath, flagPaint);

    // Phần ở giữa
    final whitePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final whitePath = Path()
      ..moveTo(1, 9)
      ..lineTo(9.9, 9)
      ..cubicTo(10.4601, 9, 10.7401, 9, 10.954, 8.89101)
      ..cubicTo(11.1422, 8.79513, 11.2951, 8.64215, 11.391, 8.45399)
      ..cubicTo(11.5, 8.24008, 11.5, 7.96005, 11.5, 7.4)
      ..lineTo(11.5, 2.1)
      ..cubicTo(11.5, 1.53995, 11.5, 1.25992, 11.391, 1.04601)
      ..cubicTo(11.2951, 0.857847, 11.1422, 0.704867, 10.954, 0.608993)
      ..cubicTo(10.7401, 0.5, 10.4601, 0.5, 9.9, 0.5)
      ..lineTo(2.6, 0.5)
      ..cubicTo(2.03995, 0.5, 1.75992, 0.5, 1.54601, 0.608993)
      ..cubicTo(1.35785, 0.704867, 1.20487, 0.857847, 1.10899, 1.04601)
      ..cubicTo(1, 1.25992, 1, 1.53995, 1, 2.1)
      ..lineTo(1, 9)
      ..close();
    canvas.drawPath(whitePath, whitePaint);

    // Cán cờ
    final polePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.75
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final polePath = Path()
      ..moveTo(1, 19)
      ..lineTo(1, 1.5)
      ..moveTo(1, 9)
      // ..lineTo(9.9, 9)
      ..close();
    canvas.drawPath(polePath, polePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is FlagPainter) {
      return oldDelegate.color != color ||
          oldDelegate.canvasWidth != canvasWidth ||
          oldDelegate.canvasHeight != canvasHeight;
    }
    return true;
  }
}
