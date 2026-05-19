import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const int _forwardMs  = 1100;
  static const int _pauseMs    = 400;
  static const int _backwardMs = 1100;
  static const int _totalMs    = _forwardMs + _pauseMs + _backwardMs;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _controller.forward().then((_) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 500),
                  pageBuilder: (_, __, ___) => const HomeScreen(),
                  transitionsBuilder: (_, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                ),
              );
            }
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFDAB9),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final elapsed = _controller.value * _totalMs;
            return CustomPaint(
              size: const Size(320, 80),
              painter: SplashPainter(elapsedMs: elapsed),
            );
          },
        ),
      ),
    );
  }
}

class SplashPainter extends CustomPainter {
  final double elapsedMs;

  static const String text      = 'GEARBOX';
  static const double fontSize  = 48;
  static const double hexR      = 34;
  static const Color  orange    = Color(0xFFFF4D00);
  static const Color  textColor = Color(0xFF1A1A1A);
  static const Color  bgColor   = Color(0xFFFFDAB9);

  static const int _forwardMs  = 1100;
  static const int _pauseMs    = 400;
  static const int _backwardMs = 1100;

  SplashPainter({required this.elapsedMs});

  double _easeInOut(double t) =>
      t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: textColor,
    );

    // Measure full text width
    final fullPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final totalTextW = fullPainter.width;
    final startX     = (size.width - totalTextW) / 2;
    final cy         = size.height / 2;

    // Per-character positions
    final List<_CharInfo> chars = [];
    double cx = 0;
    for (int i = 0; i < text.length; i++) {
      final cp = TextPainter(
        text: TextSpan(text: text[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      chars.add(_CharInfo(ch: text[i], x: startX + cx, w: cp.width));
      cx += cp.width;
    }

    final hexStartX = startX - hexR - 14;
    final hexEndX   = startX + totalTextW + hexR + 14;

    // ← hex only comes back to the midpoint (50%) on return
    final hexMidX   = hexStartX + (hexEndX - hexStartX) * 0.5;

    double hexX;
    double rollAngle;
    bool showText;
    bool hidden = false;

    if (elapsedMs < _forwardMs) {
      // Phase 1: rolling right → revealing text
      final t = _easeInOut(elapsedMs / _forwardMs);
      hexX      = hexStartX + (hexEndX - hexStartX) * t;
      rollAngle = (hexX - hexStartX) / hexR;
      showText  = true;

    } else if (elapsedMs < _forwardMs + _pauseMs) {
      // Phase 2: pause — all text visible, hex at end
      hexX      = hexEndX;
      rollAngle = (hexEndX - hexStartX) / hexR;
      showText  = true;

    } else if (elapsedMs < _forwardMs + _pauseMs + _backwardMs) {
      // Phase 3: rolling left → back to midpoint only, text hidden
      final rt = (elapsedMs - _forwardMs - _pauseMs) / _backwardMs;
      final t  = _easeInOut(rt);
      hexX      = hexEndX - (hexEndX - hexMidX) * t; // ← stops at midpoint
      rollAngle = (hexEndX - hexStartX) / hexR
                - (hexEndX - hexMidX) / hexR * t;    // ← angle matches
      showText  = false; // ← no text on the way back

    } else {
      hidden = true;
      hexX      = hexMidX;
      rollAngle = 0;
      showText  = false;
    }

    if (hidden) return;

    // Draw characters (only during forward + pause phases)
    if (showText) {
      for (final c in chars) {
        final charCX = c.x + c.w / 2;
        double opacity = 0.0;

        if (charCX < hexX - hexR * 0.3) {
          opacity = 1.0;
        } else if (charCX < hexX + hexR * 0.5) {
          opacity = ((hexX - charCX + hexR * 0.5) / (hexR * 0.8))
              .clamp(0.0, 1.0);
        }

        if (opacity > 0) {
          final cp = TextPainter(
            text: TextSpan(
              text: c.ch,
              style: textStyle.copyWith(
                color: textColor.withOpacity(opacity),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          cp.paint(canvas, Offset(c.x, cy - fontSize / 2 - 2));
        }
      }
    }

    // Draw hex nut
    _drawHex(canvas, Offset(hexX, cy), hexR, rollAngle);
  }

  void _drawHex(Canvas canvas, Offset center, double r, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // Outer hex
    final outerPath = Path();
    for (int i = 0; i < 6; i++) {
      final a  = pi / 3 * i;
      final px = r * cos(a);
      final py = r * sin(a);
      i == 0 ? outerPath.moveTo(px, py) : outerPath.lineTo(px, py);
    }
    outerPath.close();
    canvas.drawPath(outerPath, Paint()..color = orange);

    // Inner hole
    final innerPath = Path();
    for (int i = 0; i < 6; i++) {
      final a  = pi / 3 * i;
      final px = r * 0.46 * cos(a);
      final py = r * 0.46 * sin(a);
      i == 0 ? innerPath.moveTo(px, py) : innerPath.lineTo(px, py);
    }
    innerPath.close();
    canvas.drawPath(innerPath, Paint()..color = bgColor);

    canvas.restore();
  }

  @override
  bool shouldRepaint(SplashPainter old) => old.elapsedMs != elapsedMs;
}

class _CharInfo {
  final String ch;
  final double x;
  final double w;
  const _CharInfo({required this.ch, required this.x, required this.w});
}