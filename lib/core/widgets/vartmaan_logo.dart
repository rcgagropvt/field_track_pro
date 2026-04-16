import 'package:flutter/material.dart';

/// Vartmaan Pulse Logo
/// Concept: A rising pulse/heartbeat line that forms a 'V',
/// symbolising vitality, growth, and real-time tracking.
class VartmaanLogo extends StatelessWidget {
  final double size;
  final Color? color;
  const VartmaanLogo({super.key, this.size = 40, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF006A61);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(c)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color color;
  _LogoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Circle background
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      w / 2,
      Paint()..color = color.withOpacity(0.12),
    );

    // Pulse/V line path
    // Starts left, dips down, rises to peak (V shape), then flat line right
    final path = Path()
      ..moveTo(w * 0.08, h * 0.50)          // start left flat
      ..lineTo(w * 0.27, h * 0.50)          // flat
      ..lineTo(w * 0.38, h * 0.72)          // dip down (left V)
      ..lineTo(w * 0.50, h * 0.22)          // peak up (center V)
      ..lineTo(w * 0.62, h * 0.58)          // down right
      ..lineTo(w * 0.72, h * 0.50)          // back to mid
      ..lineTo(w * 0.92, h * 0.50);         // flat right

    canvas.drawPath(path, paint);

    // Dot at peak — accent
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.22),
      w * 0.055,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.color != color;
}

/// Full wordmark row: logo + "Vartmaan Pulse" text
class VartmaanWordmark extends StatelessWidget {
  final double size;
  final Color? color;
  final Color? textColor;
  const VartmaanWordmark({
    super.key,
    this.size = 32,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF006A61);
    final tc = textColor ?? const Color(0xFF1A1F36);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VartmaanLogo(size: size, color: c),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vartmaan',
              style: TextStyle(
                fontSize: size * 0.44,
                fontWeight: FontWeight.w800,
                color: c,
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
            Text(
              'PULSE',
              style: TextStyle(
                fontSize: size * 0.28,
                fontWeight: FontWeight.w600,
                color: tc.withOpacity(0.55),
                letterSpacing: 2.5,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}


