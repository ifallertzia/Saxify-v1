import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/theme/saxify_fonts.dart';

import '../../core/theme/saxify_accents.dart';

/// Saxify's own mark — a neon "S" soundwave on a rounded gradient tile.
///
/// Drawn with [CustomPainter] so it stays razor sharp at every size and picks up
/// whatever accent the app is wearing right now. It is an original design; it
/// deliberately borrows nothing from any third-party streaming brand.
class SaxifyLogo extends StatelessWidget {
  const SaxifyLogo({
    super.key,
    this.size = 40,
    this.accent,
    this.showTile = true,
    this.strokeColor,
  });

  final double size;
  final SaxifyAccent? accent;
  final bool showTile;

  /// Override the S colour (defaults to white for contrast on the gradient).
  final Color? strokeColor;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent effective =
        accent ?? Theme.of(context).extension<SaxifyAccentExtension>()?.accent ??
            SaxifyAccents.neonViolet;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SaxifyLogoPainter(
          accent: effective,
          showTile: showTile,
          strokeColor: strokeColor ?? Colors.white,
        ),
      ),
    );
  }
}

class _SaxifyLogoPainter extends CustomPainter {
  _SaxifyLogoPainter({
    required this.accent,
    required this.showTile,
    required this.strokeColor,
  });

  final SaxifyAccent accent;
  final bool showTile;
  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = math.min(size.width, size.height);

    if (showTile) {
      final RRect tile = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s, s),
        Radius.circular(s * 0.26),
      );

      // Base gradient.
      final Paint base = Paint()
        ..shader = LinearGradient(
          colors: accent.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, s, s));
      canvas.drawRRect(tile, base);

      // Deep vignette so the mark reads on every accent.
      final Paint vignette = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.85, -0.85),
          radius: 1.25,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.55),
          ],
        ).createShader(Rect.fromLTWH(0, 0, s, s));
      canvas.drawRRect(tile, vignette);
    }

    // ---- the "S" soundwave -------------------------------------------------
    final Path sPath = Path()
      ..moveTo(s * 0.71, s * 0.26)
      ..cubicTo(s * 0.66, s * 0.13, s * 0.30, s * 0.10, s * 0.26, s * 0.30)
      ..cubicTo(s * 0.21, s * 0.50, s * 0.79, s * 0.50, s * 0.74, s * 0.70)
      ..cubicTo(s * 0.70, s * 0.91, s * 0.31, s * 0.89, s * 0.27, s * 0.75);

    // Glow pass.
    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = s * 0.20
      ..color = strokeColor.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(sPath, glow);

    // Crisp pass.
    final Paint ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = s * 0.115
      ..color = strokeColor;
    canvas.drawPath(sPath, ink);

    // ---- equalizer ticks: three dots that make it a *music* mark -----------
    final Paint dot = Paint()..color = strokeColor.withValues(alpha: 0.92);
    const List<double> heights = <double>[0.10, 0.16, 0.07];
    for (int i = 0; i < heights.length; i++) {
      final double x = s * (0.30 + i * 0.20);
      final double h = s * heights[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - s * 0.018, s * 0.86 - h, s * 0.036, h),
          Radius.circular(s * 0.018),
        ),
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_SaxifyLogoPainter oldDelegate) =>
      oldDelegate.accent.id != accent.id ||
      oldDelegate.showTile != showTile ||
      oldDelegate.strokeColor != strokeColor;
}

/// Logo tile + wordmark, the way the site's sidebar shows it.
class SaxifyWordmark extends StatelessWidget {
  const SaxifyWordmark({
    super.key,
    this.logoSize = 34,
    this.fontSize = 20,
    this.showSubtitle = false,
    this.accent,
  });

  final double logoSize;
  final double fontSize;
  final bool showSubtitle;
  final SaxifyAccent? accent;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent effective =
        accent ?? Theme.of(context).extension<SaxifyAccentExtension>()?.accent ??
            SaxifyAccents.neonViolet;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SaxifyLogo(size: logoSize, accent: effective),
        SizedBox(width: logoSize * 0.3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ShaderMask(
              shaderCallback: (Rect bounds) =>
                  effective.horizontalGradient.createShader(bounds),
              child: Text(
                'Saxify',
                style: SaxifyFonts.display(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: Colors.white,
                ),
              ),
            ),
            if (showSubtitle)
              const Text(
                'Stream beyond limits',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF8D87A6)),
              ),
          ],
        ),
      ],
    );
  }
}
