import 'package:flutter/material.dart';

import '../../core/theme/glass.dart';
import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';

/// Compatibility layer.
///
/// The whole app now paints with the **Liquid Glass** system in
/// `core/theme/glass.dart`. These names are kept so every screen keeps
/// compiling while it renders the new Apple-style material.
export '../../core/theme/glass.dart'
    show
        SectionHeader,
        EmptyState,
        LoadingRail,
        NeonDivider,
        GlassPanel,
        GlassButton,
        GlassIconButton,
        GlassSheet,
        GlassProgress,
        GlassListTile,
        GlassTag,
        AuroraBackdrop;

/// Text painted with the live accent gradient — the headlines.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, this.style, this.accent});

  final String text;
  final TextStyle? style;
  final SaxifyAccent? accent;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent effective = accent ?? context.accent;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) =>
          effective.horizontalGradient.createShader(bounds),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}

/// Frosted card surface. Thin wrapper over [GlassPanel] kept for older call
/// sites (`NeonCard` was the app's original neon card).
class NeonCard extends StatelessWidget {
  const NeonCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.radius = SaxifyTheme.radiusLg,
    this.background,
    this.borderColor,
    this.glow = false,
    this.blur = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;
  final Color? background;
  final Color? borderColor;
  final bool glow;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    final BorderRadius br = BorderRadius.circular(radius);
    return Padding(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          splashColor: accent.primary.withValues(alpha: 0.10),
          highlightColor: accent.primary.withValues(alpha: 0.05),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: br,
              color: background ?? Colors.white.withValues(alpha: 0.045),
              border: Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.09),
              ),
              boxShadow: <BoxShadow>[
                if (glow)
                  BoxShadow(
                    color: accent.primary.withValues(alpha: 0.24),
                    blurRadius: 34,
                    spreadRadius: -12,
                    offset: const Offset(0, 12),
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 22,
                  spreadRadius: -14,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Big liquid-glass button (`NeonButton` is the historical name).
class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.filled = true,
    this.expand = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GlassButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      filled: filled,
      expand: expand,
      compact: compact,
    );
  }
}
