import 'package:flutter/material.dart';

import '../../core/theme/sidify_theme.dart';

/// Network artwork with a neon placeholder and graceful failure.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.url,
    this.size,
    this.width,
    this.height,
    this.radius = SidifyTheme.radiusSm,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.music_note_rounded,
  });

  final String url;
  final double? size;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final double w = width ?? size ?? 56;
    final double h = height ?? size ?? 56;
    final Widget placeholder = _Fallback(radius: radius, icon: fallbackIcon);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: w,
        height: h,
        child: url.isEmpty
            ? placeholder
            : Image.network(
                url,
                width: w,
                height: h,
                fit: fit,
                gaplessPlayback: true,
                errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                    placeholder,
                loadingBuilder: (BuildContext c, Widget child,
                    ImageChunkEvent? progress) {
                  if (progress == null) return child;
                  return Container(
                    color: SidifyColors.surfaceAlt,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.radius, required this.icon});

  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF221C36), Color(0xFF141121)],
        ),
      ),
      child: Center(
        child: Icon(icon, color: SidifyColors.textFaint, size: radius * 1.6),
      ),
    );
  }
}
