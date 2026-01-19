import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../MainNavigation.dart';
import '../main.dart';
import 'Widgets/reusable.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const primaryGreen = Color(0xFF13EC5B);
  static const bgDark = Color(0xFF102216);
  static const lightGreen = Color(0xFF92C9A4);
  static const darkSurface = Color(0xFF193322);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController mainCtrl;
  late final AnimationController shimmerCtrl;
  late final AnimationController pulseCtrl;
  late final AnimationController progressCtrl;
  late final AnimationController particleCtrl;

  late final Animation<double> fade;
  late final Animation<double> scale;
  late final Animation<double> slide;
  late final Animation<double> taglineFade;
  late final Animation<double> taglineSlide;
  late final Animation<double> pulse;
  late final Animation<double> progress;

  final rnd = Random();
  late final List<_Particle> particles;

  @override
  void initState() {
    super.initState();

    mainCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500));
    particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

    fade = CurvedAnimation(parent: mainCtrl, curve: const Interval(0, .5));
    scale = CurvedAnimation(parent: mainCtrl, curve: const Interval(0, .6, curve: Curves.elasticOut));
    slide = Tween(begin: 50.0, end: 0.0).animate(mainCtrl);
    taglineFade = CurvedAnimation(parent: mainCtrl, curve: const Interval(.4, .8));
    taglineSlide = Tween(begin: 30.0, end: 0.0).animate(mainCtrl);
    pulse = Tween(begin: 1.0, end: 1.1).animate(pulseCtrl);
    progress = CurvedAnimation(parent: progressCtrl, curve: Curves.easeInOut);

    particles = List.generate(
      20,
          (_) => _Particle(
        rnd.nextDouble(),
        rnd.nextDouble(),
        rnd.nextDouble() * 8 + 4,
        rnd.nextDouble() * .3 + .1,
        rnd.nextDouble() * .5 + .2,
      ),
    );

    mainCtrl.forward();
    progressCtrl.forward();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (_, a, __) => const MainNavigationScreen(),
            transitionsBuilder: (_, a, __, c) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .1), end: Offset.zero).animate(a),
                child: c,
              ),
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    mainCtrl.dispose();
    shimmerCtrl.dispose();
    pulseCtrl.dispose();
    progressCtrl.dispose();
    particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide > 600;

    return Scaffold(
      backgroundColor: SplashScreen.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: mainCtrl,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5 + mainCtrl.value * 0.5,
                  colors: [SplashScreen.darkSurface, SplashScreen.bgDark, Colors.black],
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: mainCtrl,
            builder: (_, __) => CustomPaint(painter: _CirclesPainter(mainCtrl.value)),
          ),
          AnimatedBuilder(
            animation: shimmerCtrl,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + shimmerCtrl.value * 2, -1),
                  end: Alignment(1 + shimmerCtrl.value * 2, 1),
                  colors: [
                    SplashScreen.primaryGreen.withValues(alpha: 0.03),
                    Colors.transparent,
                    SplashScreen.primaryGreen.withValues(alpha: 0.05),
                    Colors.transparent,
                    SplashScreen.lightGreen.withValues(alpha: 0.03),
                  ],
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Colors.black.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.7)],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: particleCtrl,
            builder: (_, __) => CustomPaint(painter: _ParticlePainter(particles, particleCtrl.value)),
          ),
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([mainCtrl, pulseCtrl, shimmerCtrl]),
              builder: (_, __) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: pulse.value,
                    child: Opacity(
                      opacity: fade.value,
                      child: Container(
                        // Responsive Size: 30% of screen width, clamped between 100 and 200
                        width: (size.width * 0.3).clamp(100.0, 200.0),
                        height: (size.width * 0.3).clamp(100.0, 200.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [SplashScreen.primaryGreen, Color(0xFF0FD850)],
                          ),
                          boxShadow: [
                            BoxShadow(color: SplashScreen.primaryGreen.withValues(alpha: 0.6), blurRadius: 40, spreadRadius: 10),
                            BoxShadow(color: SplashScreen.primaryGreen.withValues(alpha: 0.3), blurRadius: 80, spreadRadius: 20),
                          ],
                        ),
                        child: Icon(Icons.toll, color: const Color(0xFF102216), size: (size.width * 0.15).clamp(50.0, 100.0)),
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.05),
                  Transform.translate(
                    offset: Offset(0, slide.value),
                    child: Opacity(
                      opacity: fade.value,
                      child: Transform.scale(
                        scale: scale.value,
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            begin: Alignment(-2 + shimmerCtrl.value * 4, 0),
                            end: Alignment(0 + shimmerCtrl.value * 4, 0),
                            colors: const [Colors.white, SplashScreen.primaryGreen, Colors.white],
                          ).createShader(bounds),
                          blendMode: BlendMode.srcIn,
                          child: Text(
                            'Coinium',
                            // Responsive text size
                            style: TextStyle(
                              fontSize: isTablet ? 64 : 48,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Transform.translate(
                    offset: Offset(0, taglineSlide.value),
                    child: Opacity(opacity: taglineFade.value, child: const _Typewriter()),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 48,
            right: 48,
            child: AnimatedBuilder(
              animation: Listenable.merge([progressCtrl, shimmerCtrl]),
              builder: (_, __) => Column(
                children: [
                  Text(
                    '${(progress.value * 100).toInt()}%',
                    style: TextStyle(
                      color: SplashScreen.lightGreen.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: SplashScreen.darkSurface.withValues(alpha: 0.5),
                      border: Border.all(color: SplashScreen.primaryGreen.withValues(alpha: 0.2)),
                    ),
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          widthFactor: progress.value,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(colors: [SplashScreen.primaryGreen, Color(0xFF0FD850)]),
                              boxShadow: [BoxShadow(color: SplashScreen.primaryGreen.withValues(alpha: 0.5), blurRadius: 15, spreadRadius: 2)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: mainCtrl,
              builder: (_, __) => Opacity(
                opacity: taglineFade.value * .7,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: SplashScreen.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: SplashScreen.primaryGreen.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 14, color: SplashScreen.primaryGreen),
                          const SizedBox(width: 6),
                          Text(
                            'Powered by Gemini AI',
                            style: TextStyle(
                              color: SplashScreen.lightGreen.withValues(alpha: 0.9),
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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
class _CirclesPainter extends CustomPainter {
  final double progress;
  _CirclesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 1; i <= 3; i++) {
      paint.color = SplashScreen.primaryGreen.withValues(alpha: 0.1 * (4 - i) * progress);
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), (100 + i * 80) * progress, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CirclesPainter oldDelegate) => oldDelegate.progress != progress;
}

class _Particle {
  double x, y, size, speed, opacity;
  _Particle(this.x, this.y, this.size, this.speed, this.opacity);
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double time;
  _ParticlePainter(this.particles, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final y = (p.y - time * p.speed) % 1;
      final paint = Paint()
        ..color = SplashScreen.primaryGreen.withValues(alpha: p.opacity * (1 - y * 0.5))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(p.x * size.width, y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => oldDelegate.time != time;
}
class _Typewriter extends StatefulWidget {
  const _Typewriter();

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter> with SingleTickerProviderStateMixin {
  static const text = 'Scan. Identify. Collect.';
  late final AnimationController ctrl;
  String displayText = '';

  @override
  void initState() {
    super.initState();
    ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) ctrl.forward();
    });
    ctrl.addListener(_updateText);
  }

  void _updateText() {
    final charCount = (text.length * ctrl.value).round();
    if (mounted) setState(() => displayText = text.substring(0, charCount));
  }

  @override
  void dispose() {
    ctrl.removeListener(_updateText);
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayText,
          style: const TextStyle(
            color: SplashScreen.lightGreen,
            fontSize: 18,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (ctrl.value < 1.0) const BlinkingCursor(),
      ],
    );
  }
}
