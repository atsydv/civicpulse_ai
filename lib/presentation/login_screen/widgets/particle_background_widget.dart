import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class _Particle {
  double x, y, radius, opacity, speed, angle;
  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
    required this.speed,
    required this.angle,
  });
}

class ParticleBackgroundWidget extends StatefulWidget {
  const ParticleBackgroundWidget({super.key});

  @override
  State<ParticleBackgroundWidget> createState() =>
      _ParticleBackgroundWidgetState();
}

class _ParticleBackgroundWidgetState extends State<ParticleBackgroundWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = math.Random(42);

  @override
  void initState() {
    super.initState();
    _particles = List.generate(
      40,
      (i) => _Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        radius: 1.0 + _random.nextDouble() * 2.5,
        opacity: 0.2 + _random.nextDouble() * 0.4,
        speed: 0.00008 + _random.nextDouble() * 0.00012,
        angle: _random.nextDouble() * math.pi * 2,
      ),
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ParticlePainter(_particles, _controller.value),
      size: Size.infinite,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double tick;

  _ParticlePainter(this.particles, this.tick);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (tick + p.speed * 1000) % 1.0;
      final x = (p.x + math.cos(p.angle) * t * 0.3) % 1.0;
      final y = (p.y + math.sin(p.angle) * t * 0.3) % 1.0;

      final paint = Paint()
        ..color = AppTheme.primary.withOpacity(p.opacity * 0.6)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.tick != tick;
}
