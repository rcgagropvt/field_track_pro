import 'dart:math';
import 'package:flutter/material.dart';

class MilestoneCelebration extends StatefulWidget {
  final String title;
  final String description;
  final String icon;
  final VoidCallback onDismiss;

  const MilestoneCelebration({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onDismiss,
  });

  static Future<void> show(BuildContext context, {
    required String title,
    required String description,
    String icon = '🏆',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MilestoneCelebration(
        title: title,
        description: description,
        icon: icon,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  State<MilestoneCelebration> createState() => _MilestoneCelebrationState();
}

class _MilestoneCelebrationState extends State<MilestoneCelebration>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late Animation<double> _scaleAnimation;
  final List<_Confetti> _confettiPieces = [];
  final _random = Random();

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..addListener(() => setState(() {}));

    // Generate confetti
    for (int i = 0; i < 60; i++) {
      _confettiPieces.add(_Confetti(
        x: _random.nextDouble() * 400 - 200,
        y: -_random.nextDouble() * 200,
        speed: _random.nextDouble() * 300 + 200,
        angle: _random.nextDouble() * 2 * pi,
        rotationSpeed: _random.nextDouble() * 6 - 3,
        size: _random.nextDouble() * 10 + 5,
        color: [
          Colors.red, Colors.blue, Colors.green, Colors.amber,
          Colors.purple, Colors.orange, Colors.pink, Colors.teal,
        ][_random.nextInt(8)],
      ));
    }

    _scaleController.forward();
    _confettiController.forward();

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Stack(
        children: [
          // Confetti
          ..._confettiPieces.map((c) {
            final progress = _confettiController.value;
            final y = c.y + c.speed * progress;
            final x = c.x + sin(c.angle + progress * c.rotationSpeed) * 30;
            final opacity = (1 - progress).clamp(0.0, 1.0);

            return Positioned(
              left: MediaQuery.of(context).size.width / 2 + x,
              top: MediaQuery.of(context).size.height / 3 + y,
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: c.angle + progress * c.rotationSpeed * 2,
                  child: Container(
                    width: c.size,
                    height: c.size * 0.6,
                    decoration: BoxDecoration(
                      color: c.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            );
          }),
          // Main card
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                margin: const EdgeInsets.all(40),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.icon, style: const TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    const Text(
                      'MILESTONE UNLOCKED!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: widget.onDismiss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('AWESOME!', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Confetti {
  final double x, y, speed, angle, rotationSpeed, size;
  final Color color;
  _Confetti({
    required this.x, required this.y, required this.speed,
    required this.angle, required this.rotationSpeed,
    required this.size, required this.color,
  });
}
