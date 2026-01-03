// lib/components/branded_loader.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

class BrandedLoader extends StatefulWidget {
  final String brandName;
  final double size;
  final Color? primaryColor;
  final Color? secondaryColor;

  const BrandedLoader({
    super.key,
    this.brandName = 'Bettbit',
    this.size = 80.0,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  State<BrandedLoader> createState() => _BrandedLoaderState();
}

class _BrandedLoaderState extends State<BrandedLoader>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _orbitController;

  @override
  void initState() {
    super.initState();

    // Rotation animation for outer ring
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // Pulse animation for the letter
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Orbit animation for particles
    _orbitController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor ?? const Color(0xFF6366F1);
    final secondaryColor = widget.secondaryColor ?? const Color(0xFF8B5CF6);
    final firstLetter = widget.brandName.isNotEmpty 
        ? widget.brandName[0].toUpperCase() 
        : 'B';

    return Center(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer rotating ring with gradient
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * math.pi,
                  child: CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _OuterRingPainter(
                      color1: primaryColor,
                      color2: secondaryColor,
                    ),
                  ),
                );
              },
            ),

            // Middle rotating ring (opposite direction)
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: -_rotationController.value * 1.5 * math.pi,
                  child: CustomPaint(
                    size: Size(widget.size * 0.75, widget.size * 0.75),
                    painter: _MiddleRingPainter(
                      color1: primaryColor.withOpacity(0.6),
                      color2: secondaryColor.withOpacity(0.6),
                    ),
                  ),
                );
              },
            ),

            // Orbiting particles
            AnimatedBuilder(
              animation: _orbitController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _OrbitingParticlesPainter(
                    progress: _orbitController.value,
                    color1: primaryColor,
                    color2: secondaryColor,
                  ),
                );
              },
            ),

            // Center circle with glow effect
            Container(
              width: widget.size * 0.5,
              height: widget.size * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryColor.withOpacity(0.3),
                    secondaryColor.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Pulsing letter in center
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.15);
                final opacity = 0.9 + (_pulseController.value * 0.1);
                
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size * 0.4,
                    height: widget.size * 0.4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withOpacity(opacity),
                          secondaryColor.withOpacity(opacity),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        firstLetter,
                        style: TextStyle(
                          fontSize: widget.size * 0.25,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Shimmer effect overlay
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _ShimmerPainter(
                    progress: _rotationController.value,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Outer ring painter
class _OuterRingPainter extends CustomPainter {
  final Color color1;
  final Color color2;

  _OuterRingPainter({
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..shader = SweepGradient(
        colors: [
          color1,
          color2,
          color1.withOpacity(0.3),
          Colors.transparent,
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
        transform: const GradientRotation(0),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Middle ring painter
class _MiddleRingPainter extends CustomPainter {
  final Color color1;
  final Color color2;

  _MiddleRingPainter({
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          color1,
          color2,
          color1.withOpacity(0.3),
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Orbiting particles painter
class _OrbitingParticlesPainter extends CustomPainter {
  final double progress;
  final Color color1;
  final Color color2;

  _OrbitingParticlesPainter({
    required this.progress,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;

    // Draw 4 orbiting particles
    for (int i = 0; i < 4; i++) {
      final angle = (progress * 2 * math.pi) + (i * math.pi / 2);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      final particlePaint = Paint()
        ..color = i % 2 == 0 
            ? color1.withOpacity(0.8) 
            : color2.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 3, particlePaint);

      // Glow effect
      final glowPaint = Paint()
        ..color = i % 2 == 0 
            ? color1.withOpacity(0.3) 
            : color2.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(Offset(x, y), 5, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_OrbitingParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Shimmer effect painter
class _ShimmerPainter extends CustomPainter {
  final double progress;

  _ShimmerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Create expanding circle effect
    final currentRadius = maxRadius * 0.5 * (1 + progress);
    final opacity = (1 - progress) * 0.2;

    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, currentRadius, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Minimal inline loader for smaller spaces
class MiniLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const MiniLoader({
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  State<MiniLoader> createState() => _MiniLoaderState();
}

class _MiniLoaderState extends State<MiniLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xFF6366F1);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  color,
                  color.withOpacity(0.1),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Full screen loader overlay
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final String brandName;

  const LoadingOverlay({
    super.key,
    this.message,
    this.brandName = 'Bettbit',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BrandedLoader(brandName: brandName),
            if (message != null) ...[
              const SizedBox(height: 24),
              Text(
                message!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}